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

public class Hub: NSObject, MessageHandler {
    
    public static let MessageKey = "XMPPMessageHubMessageKey"
    public static let DidAddMessageNotification = Notification.Name(rawValue: "XMPPMessageHubDidAddMessageNotification")
    
    let archvieManager: ArchvieManager
    
    private struct PendingMessageDispatch {
        let document: PXDocument
        let account: JID
        var completion: ((Error?) -> Void)?
    }
    
    private let queue: DispatchQueue
    private var archiveByAccount: [JID:Archive] = [:]
    private var pendingMessageDispatch: [PendingMessageDispatch] = []
    
    required public init(archvieManager: ArchvieManager) {
        self.archvieManager = archvieManager
        queue = DispatchQueue(
            label: "Hub",
            attributes: [.concurrent])
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
                if let archive = self.archiveByAccount[account] {
                    try self.insert(document, in: archive)
                    completion?(nil)
                } else {
                    let pending = PendingMessageDispatch(document: document, account: account, completion: completion)
                    self.pendingMessageDispatch.append(pending)
                    self.openArchive(for: account)
                }
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: -
    
    private func insert(_ document: PXDocument, in archive: Archive) throws {
        let now = Date()
        let metadata = Metadata(created: now, transmitted: now, read: nil, error: nil)
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
                    try self.insert(pending.document, in: archive)
                    pending.completion?(nil)
                } catch {
                    pending.completion?(error)
                }
                return false
            })
            
        }
    }
}
