//
//  MessageArchiveHandler.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import XMPPFoundation

class MessageArchiveHandler: NSObject, Handler, MessageArchiveRequestDelegate, MessageArchiveManagement {
    
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
