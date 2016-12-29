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
    
    var hub: Hub?
    
    override func setUp() {
        super.setUp()
        guard let directory = self.directory else { return }
        let archiveManager = FileArchvieManager(directory: directory)
        self.hub = Hub(archvieManager: archiveManager)
    }
    
    override func tearDown() {
        self.hub = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testReceiveMessage() {
        guard
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
        hub.handleMessage(stanza) { error in
            XCTAssertNil(error)
            dispatchExp.fulfill()
        }
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
        
        let dispatcher = Dispatcher()
        hub.messageHandler = dispatcher
        
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
    
    class Dispatcher: NSObject, MessageHandler {
        func handleMessage(_ stanza: MessageStanza, completion: ((Error?) -> Void)? = nil) {
            completion?(nil)
        }
    }
}
