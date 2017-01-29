//
//  MessageArchiveHandler.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.01.17.
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

class MessageArchiveHandler: NSObject, Handler, ConnectionHandler, MessageArchiveRequestDelegate, MessageArchiveManagement {
    
    private struct PendingRequest {
        let request: MessageArchiveRequest
        let account: JID
        let completion: ((Error?) -> Void)?
    }
    
    private let queue: DispatchQueue
    private let dispatcher: Dispatcher
    private let archvieManager: ArchiveManager
    private let indexManager: MAMIndexManager
    
    private var pendingRequests: [String: PendingRequest] = [:]
    
    required init(dispatcher: Dispatcher, archvieManager: ArchiveManager, indexManager: MAMIndexManager) {
        self.dispatcher = dispatcher
        self.archvieManager = archvieManager
        self.indexManager = indexManager
        queue = DispatchQueue(
            label: "MessageArchiveHandler",
            attributes: [.concurrent]
        )
        super.init()
        dispatcher.add(self)
    }
    
    deinit {
        dispatcher.remove(self)
    }
    
    // MARK: - MessageArchiveManagement
    
    func canLoadMoreMessages(for account: JID) -> Bool {
        return queue.sync {
            do {
                return try self.indexManager.canLoadMoreMessages(for: account)
            } catch {
                return false
            }
        }
    }
    
    func loadRecentMessages(for account: JID, completion: ((Error?) -> Void)?) {
        queue.async {
            self.fetchMessages(for: account, before: nil, completion: completion)
        }
    }
    
    func loadMoreMessages(for account: JID, completion: ((Error?) -> Void)?) {
        queue.async {
            do {
                guard
                    let nextArchvieID = try self.indexManager.nextArchvieID(for: account)
                else {
                    completion?(nil)
                    return
                }
                self.fetchMessages(for: account, before: nextArchvieID, completion: completion)
            } catch {
                completion?(error)
            }
        }
    }
    
    private func fetchMessages(for account: JID, before archvieID: MessageArchiveID?, completion: ((Error?) -> Void)?) {
        self.archvieManager.archive(for: account, create: true) { archive, error in
            guard
                let archive = archive
            else {
                completion?(error)
                return
            }
            
            self.queue.async {
                do {
                    let request = MessageArchiveRequestImpl(dispatcher: self.dispatcher, archive: archive)
                    request.delegate = self
                    try request.performFetch(before: archvieID, limit: 20, timeout: 120.0)
                    self.pendingRequests[request.queryID] = PendingRequest(request: request, account: account, completion: completion)
                } catch {
                    completion?(error)
                }
            }
        }
    }
    
    // MARK: - ConnectionHandler
    
    func didConnect(_ JID: JID, resumed: Bool, features: [Feature]?) {
        queue.async {
            let mamFeature = Feature(identifier: "urn:xmpp:mam:1")
            if resumed == false && (features == nil || features!.contains(mamFeature)) {
                self.fetchMessages(for: JID, before: nil) { error in
                    if error != nil {
                        NSLog("Failed to load recent messages for account '\(JID)': \(error)")
                    }
                }
            }
        }
    }
    
    func didDisconnect(_: JID) {
        
    }
    
    // MARK: - MessageArchiveRequestDelegate
    
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFinishWith response: MAMIndexPartition) {
        queue.sync {
            guard
                let pendingRequest = self.pendingRequests[request.queryID]
            else { return }
            
            self.pendingRequests[request.queryID] = nil
            
            do {
                try self.indexManager.add(response, for: pendingRequest.account)
                pendingRequest.completion?(nil)
            } catch {
                pendingRequest.completion?(error)
            }
        }
    }
    
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFailWith error: Error) {
        queue.sync {
            guard
                let pendingRequest = self.pendingRequests[request.queryID]
            else { return }
            self.pendingRequests[request.queryID] = nil
            pendingRequest.completion?(error)
        }
    }
}
