//
//  InboundMesageHandler.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016, 2017 Tobias Kräntzer.
//
//  This file is part of XMPPMessageHub.
//
//  XMPPMessageHub is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  XMPPMessageHub is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  XMPPMessageHub. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
//


import Foundation
import PureXML
import XMPPFoundation

enum InboundMesageHandlerError: Error {
    case invalidDocument
}

protocol InboundMesageHandlerDelegate: class {
    func inboundMessageHandler(_ handler: InboundMesageHandler, didReceive message: Message, userInfo: [AnyHashable: Any]) -> Void
}

class InboundMesageHandler: NSObject, MessageHandler {
    
    weak var delegate: InboundMesageHandlerDelegate?
    
    private struct PendingMessageDispatch {
        let message: MessageStanza
        let metadata: Metadata
        let userInfo: [AnyHashable: Any]
        let account: JID
        var completion: ((Error?) -> Void)?
    }
    
    private var archiveByAccount: [JID: Archive] = [:]
    private var pendingMessageDispatch: [PendingMessageDispatch] = []
    private let queue: DispatchQueue
    private let dispatcher: Dispatcher
    private let archvieManager: ArchiveManager
    private let inboundFilter: [MessageFilter]
    
    required init(dispatcher: Dispatcher, archvieManager: ArchiveManager) {
        self.dispatcher = dispatcher
        self.archvieManager = archvieManager
        self.inboundFilter = [
            MessageCarbonsFilter(direction: .received).optional,
            MessageCarbonsFilter(direction: .sent).optional,
            MessageArchiveManagementFilter().inverte
        ]
        queue = DispatchQueue(
            label: "InboundMesageHandler",
            attributes: [.concurrent]
        )
        super.init()
        dispatcher.add(self)
    }
    
    deinit {
        dispatcher.remove(self)
    }
    
    // MARK: - CoreXMPP.MessageHandler
    
    func handleMessage(
        _ message: MessageStanza,
        completion: ((Error?) -> Void)?
    ) {
        guard
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
                let initial: MessageFilter.Result? = (message: message, metadata: metadata, userInfo: [:])
                let filtered = try self.inboundFilter.reduce(initial) { input, filter in
                    guard
                        let result = input
                    else { return nil }
                    return try filter.apply(to: result.message, with: result.metadata, userInfo: result.userInfo)
                }
                
                guard
                    let result = filtered
                else {
                    completion?(nil)
                    return
                }
                
                if let archive = self.archiveByAccount[account] {
                    try self.insert(result.message, with: result.metadata, userInfo: result.userInfo, in: archive)
                    completion?(nil)
                } else {
                    let pending = PendingMessageDispatch(message: result.message, metadata: result.metadata, userInfo: result.userInfo, account: account, completion: completion)
                    self.pendingMessageDispatch.append(pending)
                    self.openArchive(for: account)
                }
                
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: -
    
    private func insert(_ stanza: MessageStanza, with metadata: Metadata, userInfo: [AnyHashable: Any], in archive: Archive) throws {
        let message = try archive.insert(stanza, metadata: metadata)
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
                    try self.insert(pending.message, with: pending.metadata, userInfo: pending.userInfo, in: archive)
                    pending.completion?(nil)
                } catch {
                    pending.completion?(error)
                }
                return false
            })
            
        }
    }
}
