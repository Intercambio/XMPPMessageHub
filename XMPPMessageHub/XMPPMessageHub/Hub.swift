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

public class Hub: NSObject, ArchvieManager, ArchiveProxyDelegate, MessageHandler, InboundMesageHandlerDelegate {
    
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
    
    private var archiveByAccount: [JID:Archive] = [:]
    private var messagesBeeingTransmitted: [MessageID] = []
    
    private let queue: DispatchQueue
    private let outboundFilter: [MessageFilter]
    private let inboundMessageHandler: InboundMesageHandler
    
    required public init(archvieManager: ArchvieManager, inboundFilter: [MessageFilter] = [], outboundFilter: [MessageFilter] = []) {
        self.archvieManager = archvieManager
        self.outboundFilter = outboundFilter
        self.inboundMessageHandler = InboundMesageHandler(archvieManager: archvieManager, inboundFilter: inboundFilter)
        queue = DispatchQueue(
            label: "Hub",
            attributes: [.concurrent])
        super.init()
        self.inboundMessageHandler.delegate = self
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
    
    // MARK: - InboundMesageHandlerDelegate
    
    func inboundMessageHandler(_ handler: InboundMesageHandler, didReceive message: Message) {
        queue.async {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Hub.DidAddMessageNotification,
                    object: self,
                    userInfo: [Hub.MessageKey:message])
            }
        }
    }
    
    // MARK: - MessageHandler
    
    public func handleMessage(_ document: PXDocument,
                              completion: ((Error?) -> Void)?) {
        queue.async {
           self.inboundMessageHandler.handleMessage(document, completion: completion)
        }
    }
}
