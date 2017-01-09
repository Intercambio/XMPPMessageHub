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

class MessageArchiveHandler: NSObject, Handler, MessageArchiveRequestDelegate {
    
    private let queue: DispatchQueue
    private let dispatcher: Dispatcher
    private let archvieManager: ArchiveManager
    
    private var archiveIndexes: [JID:MessageArchiveIndex] = [:]
    private var pendingRequests: [MessageArchiveRequest:JID] = [:]
    
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
    
    func fetchRecentMessages(for account: JID, completion:((Error?)->Void)?) {
        queue.async {
            
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
                        try request.performFetch()
                        self.pendingRequests[request] = account
                    } catch {
                        completion?(error)
                    }
                }
            }
        }
    }
    
    // MARK: - MessageArchiveRequestDelegate
    
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFinishWith response: MessageArchivePartition) -> Void {
        queue.sync {
            guard
                let account = self.pendingRequests[request]
                else { return }
            
            self.pendingRequests[request] = nil
            
            if var index = self.archiveIndexes[account] {
                index = index.add(response)
                self.archiveIndexes[account] = index
            } else {
                self.archiveIndexes[account] = MessageArchiveIndex(partitions: [response])
            }
        }
    }
    
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFailWith error: Error) -> Void{
        
    }
    
}
