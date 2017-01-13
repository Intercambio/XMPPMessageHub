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
        let account: JID
        let completion: ((Error?) -> Void)?
    }
    
    private let queue: DispatchQueue
    private let dispatcher: Dispatcher
    private let archvieManager: ArchiveManager
    
    private var archiveIndexes: [JID:MessageArchiveIndex] = [:]
    private var pendingRequests: [String:PendingRequest] = [:]
    
    required init(dispatcher: Dispatcher, archvieManager: ArchiveManager) {
        self.dispatcher = dispatcher
        self.archvieManager = archvieManager
        queue = DispatchQueue(
            label: "MessageArchiveHandler",
            attributes: [.concurrent])
        super.init()
        dispatcher.add(self)
    }
    
    deinit {
        dispatcher.remove(self)
    }
    
    // MARK: - MessageArchiveManagement
    
    func canLoadMoreMessages(for account: JID) -> Bool {
        return queue.sync {
            guard
                let index = self.archiveIndexes[account]
                else {
                    return false
            }
            
            return index.canLoadMore
        }
    }
    
    func loadRecentMessages(for account: JID, completion:((Error?)->Void)?) {
        queue.async {
            self.fetchMessages(for: account, before: nil, completion: completion)
        }
    }
    
    func loadMoreMessages(for account: JID, completion:((Error?)->Void)?) {
        queue.async {
            guard
                let index = self.archiveIndexes[account],
                index.canLoadMore == true,
                let nextArchiveID = index.nextArchiveID
                else {
                    completion?(nil)
                    return
            }

            self.fetchMessages(for: account, before: nextArchiveID, completion: completion)
        }
    }
    
    private func fetchMessages(for account: JID, before archvieID: MessageArchiveID?, completion:((Error?)->Void)?) {
        self.archvieManager.archive(for: account, create: true) { (archive, error) in
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
                    self.pendingRequests[request.queryID] = PendingRequest(account: account, completion: completion)
                } catch {
                    completion?(error)
                }
            }
        }
    }
    
    // MARK: - MessageArchiveRequestDelegate
    
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFinishWith response: MessageArchivePartition) -> Void {
        queue.sync {
            guard
                let pendingRequest = self.pendingRequests[request.queryID]
                else { return }
            
            self.pendingRequests[request.queryID] = nil
            
            if var index = self.archiveIndexes[pendingRequest.account] {
                index = index.add(response)
                self.archiveIndexes[pendingRequest.account] = index
            } else {
                self.archiveIndexes[pendingRequest.account] = MessageArchiveIndex(partitions: [response])
            }
            
            pendingRequest.completion?(nil)
        }
    }
    
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFailWith error: Error) -> Void{
        queue.sync {
            guard
                let pendingRequest = self.pendingRequests[request.queryID]
                else { return }
            self.pendingRequests[request.queryID] = nil
            pendingRequest.completion?(error)
        }
    }
}
