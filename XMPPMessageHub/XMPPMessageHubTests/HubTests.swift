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
        guard
            let directory = self.directory,
            let dispatcher = self.dispatcher
        else { return }
        
        self.hub = Hub(dispatcher: dispatcher, directory: directory)
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
        
        var requestedArchive: Archive?
        
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
        dispatcher.send(stanza, completion: { error in
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
            let dispatcher = self.dispatcher,
            let hub = self.hub
        else { XCTFail(); return }
        
        dispatcher.messageHandler = {
            _, completion in
            completion?(nil)
        }
        
        let stanza = MessageStanza.makeDocumentWithMessageStanza(from: JID("juliet@example.com")!, to: JID("romeo@example.com")!).root as! MessageStanza
        stanza.type = .chat
        stanza.identifier = "456"
        
        var requestedArchive: Archive?
        
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
            expectation(
                forNotification: Notification.Name.ArchiveDidChange.rawValue,
                object: archive
            ) {
                notification in
                guard
                    let updated = notification.userInfo?[UpdatedMessagesKey] as? [Message],
                    let message = updated.first
                else { return false }
                return message.messageID.account == JID("romeo@example.com")!
            }
            
            _ = try archive.insert(stanza, metadata: Metadata())
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
    
    func testLoadRecentMessages() {
        guard
            let dispatcher = self.dispatcher,
            let hub = self.hub
        else { XCTFail(); return }
        
        dispatcher.IQHandler = {
            request, _, completion in
            
            let response = IQStanza.makeDocumentWithIQStanza(from: request.to, to: request.from)
            let iq = response.root as! IQStanza
            iq.type = .result
            
            let query = iq.add(withName: "fin", namespace: "urn:xmpp:mam:1", content: nil)!
            let rsm = query.add(withName: "set", namespace: "http://jabber.org/protocol/rsm", content: nil) as! XMPPResultSet
            rsm.first = "a"
            rsm.last = "b"
            rsm.count = 2
            
            completion?(iq, nil)
        }
        
        var requestedArchive: IncrementalArchive?
        let getArchiveExp = expectation(description: "Get Archive")
        hub.archive(for: JID("romeo@example.com")!, create: true) {
            archive, error in
            XCTAssertNil(error)
            requestedArchive = archive as? IncrementalArchive
            getArchiveExp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        guard
            let archive = requestedArchive
        else {
            XCTFail()
            return
        }
        
        let loadRecentExp = expectation(description: "Load Recent")
        archive.loadRecentMessages { error in
            XCTAssertNil(error)
            loadRecentExp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
