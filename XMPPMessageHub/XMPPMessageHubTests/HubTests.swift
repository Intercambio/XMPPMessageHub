//
//  HubTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 04.12.16.
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


import XCTest
import PureXML
import Dispatch
import XMPPFoundation
@testable import XMPPMessageHub

class HubTests: TestCase {
    
    var hub: MessageHub?
    
    override func setUp() {
        super.setUp()
        guard
            let directory = self.directory,
            let dispatcher = self.dispatcher
        else { return }
        
        self.hub = MessageHub(dispatcher: dispatcher, directory: directory)
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
        
        let stanza = MessageStanza(from: JID("juliet@example.com")!, to: JID("romeo@example.com")!)
        stanza.type = .chat
        stanza.identifier = "456"
        
        var requestedArchive: Archive?
        
        let getArchiveExp = expectation(description: "Get Archive")
        hub.archive(for: JID("romeo@example.com")!) {
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
        
        let stanza = MessageStanza(from: JID("juliet@example.com")!, to: JID("romeo@example.com")!)
        stanza.type = .chat
        stanza.identifier = "456"
        
        var requestedArchive: Archive?
        
        let getArchiveExp = expectation(description: "Get Archive")
        hub.archive(for: JID("romeo@example.com")!) {
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
            
            let iq = IQStanza(type: .result, from: request.to, to: request.from)
            let query = iq.add(withName: "fin", namespace: "urn:xmpp:mam:1", content: nil)
            let rsm = query.add(withName: "set", namespace: "http://jabber.org/protocol/rsm", content: nil) as! XMPPResultSet
            rsm.first = "a"
            rsm.last = "b"
            rsm.count = 2
            
            completion?(iq, nil)
        }
        
        var requestedArchive: IncrementalArchive?
        let getArchiveExp = expectation(description: "Get Archive")
        hub.archive(for: JID("romeo@example.com")!) {
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
    
    func testDeleteResources() {
        
        guard
            let directory = self.directory,
            let dispatcher = self.dispatcher,
            let hub = self.hub
            else { XCTFail(); return }

        dispatcher.IQHandler = {
            request, _, completion in
            let iq = IQStanza(type: .result, from: request.to, to: request.from)
            let query = iq.add(withName: "fin", namespace: "urn:xmpp:mam:1", content: nil)
            let rsm = query.add(withName: "set", namespace: "http://jabber.org/protocol/rsm", content: nil) as! XMPPResultSet
            rsm.first = "a"
            rsm.last = "b"
            rsm.count = 1
            completion?(iq, nil)
        }
        
        let archiveDirectory = directory.appendingPathComponent("archive/romeo@example.com", isDirectory: true)
        let mamDirectory = directory.appendingPathComponent("mam/romeo@example.com", isDirectory: true)
        let fileManager = FileManager.default
        
        XCTAssertFalse(fileManager.fileExists(atPath: archiveDirectory.path))
        XCTAssertFalse(fileManager.fileExists(atPath: mamDirectory.path))
        
        let getArchiveExp = expectation(description: "Get Archive")
        hub.archive(for: JID("romeo@example.com")!) {
            archive, error in
            XCTAssertNil(error)
            if let incrementalArchive = archive as? IncrementalArchive {
                incrementalArchive.loadRecentMessages(completion: { (error) in
                    XCTAssertNil(error)
                    getArchiveExp.fulfill()
                })
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        
        XCTAssertTrue(fileManager.fileExists(atPath: archiveDirectory.path))
        XCTAssertTrue(fileManager.fileExists(atPath: mamDirectory.path))
        
        let deleteExp = expectation(description: "Delete Resources")
        hub.deleteResources(for: JID("romeo@example.com")!) { (error) in
            XCTAssertNil(error)
            deleteExp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        XCTAssertFalse(fileManager.fileExists(atPath: archiveDirectory.path))
        XCTAssertFalse(fileManager.fileExists(atPath: mamDirectory.path))
    }
}
