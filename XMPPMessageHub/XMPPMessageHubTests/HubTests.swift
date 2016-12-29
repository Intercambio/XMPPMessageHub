//
//  HubTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
import Dispatch
import XMPPFoundation
@testable import XMPPMessageHub

class HubTests: TestCase {
    
    var dispatcher: TestDispatcher?
    var hub: Hub?
    
    override func setUp() {
        super.setUp()
        guard let directory = self.directory else { return }
        let archiveManager = FileArchvieManager(directory: directory)
        let dispatcher = TestDispatcher()
        self.dispatcher = dispatcher
        self.hub = Hub(dispatcher: dispatcher, archvieManager: archiveManager)
    }
    
    override func tearDown() {
        self.hub = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testReceiveMessage() {
        guard
            let dispatcher = self.dispatcher,
            let hub = self.hub
            else { XCTFail(); return }
        
        // Dispatch the message
        
        let stanza = MessageStanza.makeDocumentWithMessageStanza(from: JID("juliet@example.com")!, to: JID("romeo@example.com")!).root as! MessageStanza
        stanza.type = .chat
        stanza.identifier = "456"
        
        var requestedArchive: Archive? = nil
        
        let getArchiveExp = expectation(description: "Get Archive")
        hub.archive(for: JID("romeo@example.com")!, create: true) {
            archive, error in
            XCTAssertNil(error)
            XCTAssertNotNil(archive)
                requestedArchive = archive
                getArchiveExp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    
        guard
            let archive = requestedArchive
            else { return }
        
        expectation(forNotification: Notification.Name.ArchiveDidChange.rawValue, object: archive, handler: nil)
        
        let dispatchExp = self.expectation(description: "Message Handled")
        dispatcher.send(stanza, completion: { (error) in
            XCTAssertNil(error)
            dispatchExp.fulfill()
        })
        waitForExpectations(timeout: 1.0, handler: nil)
        
        do {
            let messages = try archive.all()
            XCTAssertEqual(messages.count, 1)
            
            let message = messages[0]
            let document = try archive.document(for: message.messageID)
            XCTAssertNotNil(document)
            XCTAssertEqual(document.root.value(forAttribute: "id") as? String, "456")
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testSendMessage() {
        guard
            let hub = self.hub
            else { XCTFail(); return }
        
        let stanza = MessageStanza.makeDocumentWithMessageStanza(from: JID("juliet@example.com")!, to: JID("romeo@example.com")!).root as! MessageStanza
        stanza.type = .chat
        stanza.identifier = "456"
        
        var requestedArchive: Archive? = nil
        
        let getArchiveExp = expectation(description: "Get Archive")
        hub.archive(for: JID("romeo@example.com")!, create: true) {
            archive, error in
            XCTAssertNil(error)
            XCTAssertNotNil(archive)
            requestedArchive = archive
            getArchiveExp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        guard
            let archive = requestedArchive
            else { return }
        
        do {
            expectation(forNotification: Notification.Name.ArchiveDidChange.rawValue,
                        object: archive) {
                            notification in
                            guard
                                let updated = notification.userInfo?[UpdatedMessagesKey] as? [Message],
                                let message = updated.first
                                else { return false }
                            return message.messageID.account == JID("romeo@example.com")!
            }
            
            let _ = try archive.insert(stanza, metadata: Metadata())
            waitForExpectations(timeout: 1.0, handler: nil)
            
            let messages = try archive.all()
            XCTAssertEqual(messages.count, 1)
            
            let message = messages[0]
            XCTAssertNotNil(message.metadata.transmitted)
            XCTAssertNotNil(message.messageID.originID)
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    class TestDispatcher: Dispatcher {
        
        let handlers: NSHashTable = NSHashTable<Handler>.weakObjects()
        
        func add(_ handler: Handler) {
            add(handler, withIQQueryQNames: nil)
        }
        
        func add(_ handler: Handler, withIQQueryQNames queryQNames: [PXQName]?) {
            handlers.add(handler)
        }
        
        func remove(_ handler: Handler) {
            handlers.remove(handler)
        }
        
        public func didConnect(_ JID: JID, resumed: Bool) {}
        public func didDisconnect(_ JID: JID) {}
        public func handlePresence(_ stanza: PresenceStanza, completion: ((Error?) -> Swift.Void)? = nil) {}
        public func handleIQRequest(_ stanza: IQStanza, timeout: TimeInterval, completion: ((IQStanza?, Error?) -> Swift.Void)? = nil) {}
        
        public func handleMessage(_ stanza: MessageStanza, completion: ((Error?) -> Void)? = nil) {
            completion?(nil)
        }
        
        func send(_ message: MessageStanza, completion: ((Error?)->Void)?) {
            let group = DispatchGroup()
            for handler in handlers.allObjects {
                if let messaheHandler = handler as? MessageHandler {
                    group.enter()
                    messaheHandler.handleMessage(message, completion: { (error) in
                        group.leave()
                    })
                }
            }
            group.notify(queue: DispatchQueue.main) { 
                completion?(nil)
            }
        }
    }
}
