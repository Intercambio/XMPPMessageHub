//
//  InboundMesageHandler.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import CoreXMPP

protocol InboundMesageHandlerDelegate: class {
    func inboundMessageHandler(_ handler: InboundMesageHandler, didReceive message: Message) -> Void
}

class InboundMesageHandler: NSObject, MessageHandler {
    
    weak var delegate: InboundMesageHandlerDelegate?
    
    private struct PendingMessageDispatch {
        let document: PXDocument
        let metadata: Metadata
        let account: JID
        var completion: ((Error?) -> Void)?
    }
    
    private var archiveByAccount: [JID:Archive] = [:]
    private var pendingMessageDispatch: [PendingMessageDispatch] = []
    private let queue: DispatchQueue
    private let archvieManager: ArchvieManager
    private let inboundFilter: [MessageFilter]
    
    required init(archvieManager: ArchvieManager, inboundFilter: [MessageFilter]) {
        self.archvieManager = archvieManager
        self.inboundFilter = inboundFilter
        queue = DispatchQueue(
            label: "InboundMesageHandler",
            attributes: [.concurrent])
    }
    
    // MARK: - CoreXMPP.MessageHandler
    
    func handleMessage(_ document: PXDocument,
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
        delegate?.inboundMessageHandler(self, didReceive: message)
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
