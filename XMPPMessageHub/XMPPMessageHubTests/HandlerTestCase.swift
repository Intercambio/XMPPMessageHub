//
//  HandlerTestCase.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 30.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import XMPPFoundation
@testable import XMPPMessageHub

class HandlerTestCase: TestCase {
    
    var dispatcher: TestDispatcher?
    var archiveManager: ArchiveManager?
    
    override func setUp() {
        super.setUp()
        
        guard
            let directory = self.directory
            else { return }
        
        archiveManager = FileArchvieManager(directory: directory)
    }
    
    override func tearDown() {
        archiveManager = nil
        super.tearDown()
    }
    
    func archive(for account: JID) -> Archive? {
        guard
            let archiveManager = self.archiveManager
            else { return nil }
        
        var result: Archive? = nil
        let exp = expectation(description: "Get Archive for '\(account.stringValue)'")
        archiveManager.archive(for: account, create: true) {
            archive, error in
            result = archive
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        return result
    }
    
    class TestDispatcher: Dispatcher {
        
        func send(_ message: MessageStanza, completion: ((Error?)->Void)?) {
            let group = DispatchGroup()
            for handler in handlers.allObjects {
                if let messageHandler = handler as? MessageHandler {
                    group.enter()
                    messageHandler.handleMessage(message, completion: { (error) in
                        group.leave()
                    })
                }
            }
            group.notify(queue: DispatchQueue.main) {
                completion?(nil)
            }
        }
        
        func connect(_ JID: JID, resumed: Bool = false, features: [Feature]? = nil) {
            for handler in handlers.allObjects {
                if let connectionHandler = handler as? ConnectionHandler {
                    connectionHandler.didConnect(JID, resumed: resumed, features: features)
                }
            }
        }
        
        let handlers: NSHashTable = NSHashTable<Handler>.weakObjects()
        
        func add(_ handler: Handler) {
            add(handler, withIQQueryQNames: nil, features: nil)
        }
        
        func add(_ handler: Handler, withIQQueryQNames queryQNames: [PXQName]?, features: [Feature]?) {
            handlers.add(handler)
        }
        
        func remove(_ handler: Handler) {
            handlers.remove(handler)
        }
        
        var presenceHandler: ((PresenceStanza, ((Error?) -> Void)?) -> Void)?
        public func handlePresence(_ stanza: PresenceStanza, completion: ((Error?) -> Swift.Void)? = nil) {
            presenceHandler?(stanza, completion)
        }
        
        var messageHandler: ((MessageStanza, ((Error?) -> Void)?) -> Void)?
        public func handleMessage(_ stanza: MessageStanza, completion: ((Error?) -> Void)? = nil) {
            messageHandler?(stanza, completion)
        }
        
        var IQHandler: ((IQStanza, TimeInterval, ((IQStanza?, Error?) -> Void)?) -> Void)?
        public func handleIQRequest(_ request: IQStanza,
                                    timeout: TimeInterval,
                                    completion: ((IQStanza?, Error?) -> Swift.Void)? = nil) {
            IQHandler?(request, timeout, completion)
        }
    }
}
