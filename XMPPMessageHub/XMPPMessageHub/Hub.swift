//
//  Hub.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import CoreXMPP
import PureXML

public enum HubError: Error {
    case invalidDocument
}

public class Hub: NSObject, ArchvieManager, ArchiveProxyDelegate, MessageHandler {
    
    public static let MessageKey = "XMPPMessageHubMessageKey"
    public static let DidAddMessageNotification = Notification.Name(rawValue: "XMPPMessageHubDidAddMessageNotification")
    public static let DidUpdateMessageNotification = Notification.Name(rawValue: "XMPPMessageHubDidUpdateMessageNotification")
    
    public weak var messageHandler: MessageHandler?
    
    private let archvieManager: ArchvieManager
    
    private struct PendingMessageDispatch {
        let document: PXDocument
        let metadata: Metadata
        let account: JID
        var completion: ((Error?) -> Void)?
    }
    
    private let queue: DispatchQueue
    private var archiveByAccount: [JID:Archive] = [:]
    private var pendingMessageDispatch: [PendingMessageDispatch] = []
    private var messagesBeeingTransmitted: [MessageID] = []
    
    private let inboundFilter: [MessageFilter]
    private let outboundFilter: [MessageFilter]
    
    required public init(archvieManager: ArchvieManager, inboundFilter: [MessageFilter] = [], outboundFilter: [MessageFilter] = []) {
        self.archvieManager = archvieManager
        self.inboundFilter = inboundFilter
        self.outboundFilter = outboundFilter
        queue = DispatchQueue(
            label: "Hub",
            attributes: [.concurrent])
    }
    
    // MARK: - ArchvieManager
    
    public func archive(for account: JID, create: Bool, completion: @escaping (Archive?, Error?) -> Void) -> Void {
        queue.async(flags: [.barrier]) {
            if let archive = self.archiveByAccount[account] {
                completion(ArchiveProxy(archive: archive, delegate: self), nil)
            } else {
                self.archvieManager.archive(for: account, create: create){
                    archive, error in
                    completion(archive != nil ? ArchiveProxy(archive: archive!, delegate: self) : nil, error)
                }
            }
        }
    }
    
    public func deleteArchive(for account: JID, completion: @escaping ((Error?) -> Void)) -> Void {
        queue.async(flags: [.barrier]) {
            self.archiveByAccount[account] = nil
            self.archvieManager.deleteArchive(for: account, completion: completion)
        }
    }
    
    // MARK: - ArchiveProxyDelegate
    
    func archiveProxy(_ proxy: ArchiveProxy, didInsert message: Message, with document: PXDocument) {
        queue.async(flags: [.barrier]) {
            guard
                self.messagesBeeingTransmitted.contains(message.messageID) == false,
                let handler = self.messageHandler
                else { return }
            
            do {
                let result = try self.outboundFilter.reduce((document: document, metadata: message.metadata)) { input, filter in
                    return try filter.apply(to: input.document, with: input.metadata)
                }
                
                let archive = proxy.archive
                self.messagesBeeingTransmitted.append(message.messageID)
                handler.handleMessage(result.document) { error in
                    self.queue.async(flags: [.barrier]) {
                        if let idx = self.messagesBeeingTransmitted.index(of: message.messageID) {
                            self.messagesBeeingTransmitted.remove(at: idx)
                        }
                        do {
                            let now = Date()
                            let message = try archive.update(
                                transmitted: error == nil ? now :  nil,
                                error: error as? TransmissionError,
                                for: message.messageID)
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(
                                    name: Hub.DidUpdateMessageNotification,
                                    object: self,
                                    userInfo: [Hub.MessageKey:message])
                            }
                        } catch {
                            NSLog("Failed to update message metadata: \(error)")
                        }
                    }
                }
            } catch {
                NSLog("Failed to apply outbound filter: \(error)")
            }
        }
    }
    
    // MARK: - MessageHandler
    
    public func handleMessage(_ document: PXDocument,
                              completion: ((Error?) -> Void)?) {
        guard
            let message = document.root, message.qualifiedName == PXQName(name: "message", namespace: "jabber:client")
            else { completion?(HubError.invalidDocument); return }
        
        guard
            let toString = message.value(forAttribute: "to") as? String,
            let to = JID(toString)
            else { completion?(HubError.invalidDocument); return }
        
        queue.async(flags: [.barrier]) {
            let account = to.bare()
            do {
                let now = Date()
                let metadata = Metadata(created: now, transmitted: now, read: nil, error: nil, forwarded: false)
                
                let result = try self.inboundFilter.reduce((document: document, metadata: metadata)) { input, filter in
                    return try filter.apply(to: input.document, with: input.metadata)
                }
                
                if let archive = self.archiveByAccount[account] {
                    try self.insert(result.document, with: result.metadata, in: archive)
                    completion?(nil)
                } else {
                    let pending = PendingMessageDispatch(document: result.document, metadata: result.metadata, account: account, completion: completion)
                    self.pendingMessageDispatch.append(pending)
                    self.openArchive(for: account)
                }
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: -
    
    private func insert(_ document: PXDocument, with metadata: Metadata, in archive: Archive) throws {
        let message = try archive.insert(document, metadata: metadata)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Hub.DidAddMessageNotification,
                object: self,
                userInfo: [Hub.MessageKey:message])
        }
    }
    
    private func openArchive(for account: JID) {
        archvieManager.archive(for: account, create: true) {
            archive, error in
            self.pendingMessageDispatch = self.pendingMessageDispatch.filter({ (pending) -> Bool in
                guard
                    pending.account == account
                    else { return false }
                guard
                    let archive = archive
                    else {
                        pending.completion?(error)
                        return false
                    }
                
                do {
                    try self.insert(pending.document, with: pending.metadata, in: archive)
                    pending.completion?(nil)
                } catch {
                    pending.completion?(error)
                }
                return false
            })
            
        }
    }
}
