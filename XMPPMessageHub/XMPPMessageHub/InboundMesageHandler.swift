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

class InboundMesageHandler {
    
    weak var delegate: InboundMesageHandlerDelegate?
    
    private struct PendingMessageDispatch {
        let document: PXDocument
        let metadata: Metadata
        let userInfo: [AnyHashable:Any]
        let account: JID
        var completion: ((Message?, Error?)->Void)?
    }
    
    private var archiveByAccount: [JID:Archive] = [:]
    private var pendingMessageDispatch: [PendingMessageDispatch] = []
    private let queue: DispatchQueue
    private let archvieManager: ArchvieManager
    
    required init(archvieManager: ArchvieManager) {
        self.archvieManager = archvieManager
        queue = DispatchQueue(
            label: "InboundMesageHandler",
            attributes: [.concurrent])
    }
    
    // MARK: -

    func insert(_ document: PXDocument, with metadata: Metadata, userInfo: [AnyHashable:Any], completion: ((Message?, Error?)->Void)?) {
        queue.async(flags: [.barrier]) {
            guard
                let message = document.root as? MessageStanza,
                let account = message.to?.bare()
                else {
                    completion?(nil, InboundMesageHandlerError.invalidDocument)
                    return
            }
            
            do {
                if let archive = self.archiveByAccount[account] {
                    let message = try self.insert(document, with: metadata, userInfo: userInfo, in: archive)
                    completion?(message, nil)
                } else {
                    let pending = PendingMessageDispatch(document: document, metadata: metadata, userInfo: userInfo, account: account, completion: completion)
                    self.pendingMessageDispatch.append(pending)
                    self.openArchive(for: account)
                }
            } catch {
                completion?(nil, error)
            }
        }
    }
    
    // MARK: -
    
    private func insert(_ document: PXDocument, with metadata: Metadata, userInfo: [AnyHashable:Any], in archive: Archive) throws -> Message {
        let message = try archive.insert(document, metadata: metadata)
        delegate?.inboundMessageHandler(self, didReceive: message, userInfo: userInfo)
        return message
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
                        pending.completion?(nil, error)
                        return false
                }
                
                do {
                    let message = try self.insert(pending.document, with: pending.metadata, userInfo: pending.userInfo, in: archive)
                    pending.completion?(message, nil)
                } catch {
                    pending.completion?(nil, error)
                }
                return false
            })
            
        }
    }
}
