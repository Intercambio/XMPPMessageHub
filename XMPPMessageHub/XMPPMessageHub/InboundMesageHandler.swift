//
//  InboundMesageHandler.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import XMPPFoundation

enum InboundMesageHandlerError: Error {
    case invalidDocument
}

protocol InboundMesageHandlerDelegate: class {
    func inboundMessageHandler(_ handler: InboundMesageHandler, didReceive message: Message, userInfo: [AnyHashable:Any]) -> Void
}

class InboundMesageHandler: NSObject, MessageHandler {
    
    weak var delegate: InboundMesageHandlerDelegate?
    
    private struct PendingMessageDispatch {
        let document: PXDocument
        let metadata: Metadata
        let userInfo: [AnyHashable:Any]
        let account: JID
        var completion: ((Error?) -> Void)?
    }
    
    private var archiveByAccount: [JID:Archive] = [:]
    private var pendingMessageDispatch: [PendingMessageDispatch] = []
    private let queue: DispatchQueue
    private let archvieManager: ArchvieManager
    private let inboundFilter: [MessageFilter]
    
    required init(archvieManager: ArchvieManager) {
        self.archvieManager = archvieManager
        self.inboundFilter = [
            MessageCarbonsFilter(direction: .received).optional,
            MessageCarbonsFilter(direction: .sent).optional,
            MessageArchiveManagementFilter().inverte
        ]
        queue = DispatchQueue(
            label: "InboundMesageHandler",
            attributes: [.concurrent])
    }
    
    // MARK: - CoreXMPP.MessageHandler
    
    func handleMessage(_ document: PXDocument,
                              completion: ((Error?) -> Void)?) {
        guard
            let message = document.root as? MessageStanza,
            let to = message.to
            else {
                completion?(InboundMesageHandlerError.invalidDocument)
                return
        }
        
        queue.async(flags: [.barrier]) {
            let account = to.bare()
            do {
                let now = Date()
                let metadata = Metadata(created: now, transmitted: now, read: nil, error: nil, isCarbonCopy: false)
                let initial: MessageFilter.Result? = (document: document, metadata: metadata, userInfo: [:])
                let filtered = try self.inboundFilter.reduce(initial) { input, filter in
                    guard
                        let result = input
                        else { return nil }
                    return try filter.apply(to: result.document, with: result.metadata, userInfo: result.userInfo)
                }
                
                guard
                    let result = filtered
                    else {
                        completion?(nil)
                        return
                    }
                
                if let archive = self.archiveByAccount[account] {
                    try self.insert(result.document, with: result.metadata, userInfo: result.userInfo, in: archive)
                    completion?(nil)
                } else {
                    let pending = PendingMessageDispatch(document: result.document, metadata: result.metadata, userInfo: result.userInfo, account: account, completion: completion)
                    self.pendingMessageDispatch.append(pending)
                    self.openArchive(for: account)
                }
                
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: -
    
    private func insert(_ document: PXDocument, with metadata: Metadata, userInfo: [AnyHashable:Any], in archive: Archive) throws {
        let message = try archive.insert(document, metadata: metadata)
        delegate?.inboundMessageHandler(self, didReceive: message, userInfo: userInfo)
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
                    try self.insert(pending.document, with: pending.metadata, userInfo: pending.userInfo, in: archive)
                    pending.completion?(nil)
                } catch {
                    pending.completion?(error)
                }
                return false
            })
            
        }
    }
}
