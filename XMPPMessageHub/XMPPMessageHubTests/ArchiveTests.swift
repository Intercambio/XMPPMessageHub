//
//  ArchiveTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 20.11.16.
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
import XMPPFoundation
@testable import XMPPMessageHub

class ArchiveTests: TestCase {
    
    var archive: FileArchive?
    
    override func setUp() {
        super.setUp()
        
        guard let directory = self.directory else { return }
        
        let archive = FileArchive(directory: directory, account: JID("from@example.com")!)
        
        let wait = expectation(description: "Open Archive")
        archive.open {
            error in
            XCTAssertNil(error, "Failed to open the archive: \(error?.localizedDescription)")
            wait.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        self.archive = archive
    }
    
    override func tearDown() {
        self.archive = nil
        super.tearDown()
    }
    
    // MARK: Tests
    
    func testOpenArchive() {
        
        // After opening the archive, the folder should contain a file
        // named 'version.txt' with the current version number of the
        // archive format.
        
        guard let archive = self.archive else { return }
        
        let versionFileURL = archive.directory.appendingPathComponent("version.txt")
        let versionFileText = try? String(contentsOf: versionFileURL)
        XCTAssertNotNil(versionFileText)
        
        guard let text = versionFileText else { return }
        
        let version = Int(text)
        XCTAssertEqual(version, FileArchive.Setup.version)
    }
    
    func testInsert() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        let originId = document.root.add(withName: "origin-id", namespace: "urn:xmpp:sid:0", content: nil)
        originId.setValue("1234566", forAttribute: "id")
        
        let stanzaId = document.root.add(withName: "stanza-id", namespace: "urn:xmpp:sid:0", content: nil)
        stanzaId.setValue("346", forAttribute: "id")
        stanzaId.setValue("from@example.com", forAttribute: "by")
        
        do {
            expectation(
                forNotification: Notification.Name.ArchiveDidChange.rawValue,
                object: archive
            ) { notification in
                let inserted = notification.userInfo?[InsertedMessagesKey] as? [Message]
                XCTAssertEqual(inserted?.count, 1)
                return true
            }
            
            var metadata = Metadata()
            metadata.created = Date()
            let message = try archive.insert(document, metadata: metadata)
            XCTAssertNotNil(message)
            XCTAssertEqual(message.messageID.originID, "1234566")
            XCTAssertEqual(message.messageID.stanzaID, "346")
            
            let document = try archive.document(for: message.messageID)
            XCTAssertNotNil(document)
            XCTAssertEqual(document.root.value(forAttribute: "id") as? String, "123")
            
            let messages = try archive.all()
            XCTAssertEqual(messages[0].messageID, message.messageID)
            
            waitForExpectations(timeout: 1.0, handler: nil)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testInsertDuplicateOriginID() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        let id = "1234566"
        
        let originId = document.root.add(withName: "origin-id", namespace: "urn:xmpp:sid:0", content: nil)
        originId.setValue(id, forAttribute: "id")
        
        do {
            
            let metadata = Metadata()
            let message = try archive.insert(document, metadata: metadata)
            XCTAssertNotNil(message)
            
            XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) { error in
                if let error = error as? MessageAlreadyExist {
                    XCTAssertEqual(error.existingMessageID, message.messageID)
                } else {
                    XCTFail("Expecting 'MessageAlreadyExist'")
                }
            }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testInsertDuplicateStanzaID() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        let stanzaId = document.root.add(withName: "stanza-id", namespace: "urn:xmpp:sid:0", content: nil)
        stanzaId.setValue("346", forAttribute: "id")
        stanzaId.setValue("from@example.com", forAttribute: "by")
        
        do {
            
            let metadata = Metadata()
            let message = try archive.insert(document, metadata: metadata)
            XCTAssertNotNil(message)
            
            XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) { error in
                if let error = error as? MessageAlreadyExist {
                    XCTAssertEqual(error.existingMessageID, message.messageID)
                } else {
                    XCTFail("Expecting 'MessageAlreadyExist'")
                }
            }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testInsertDuplicateHostStanzaID() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        let stanzaId = document.root.add(withName: "stanza-id", namespace: "urn:xmpp:sid:0", content: nil)
        stanzaId.setValue("346", forAttribute: "id")
        stanzaId.setValue("example.com", forAttribute: "by")
        
        do {
            
            let metadata = Metadata()
            let message = try archive.insert(document, metadata: metadata)
            XCTAssertNotNil(message)
            
            XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) { error in
                if let error = error as? MessageAlreadyExist {
                    XCTAssertEqual(error.existingMessageID, message.messageID)
                } else {
                    XCTFail("Expecting 'MessageAlreadyExist'")
                }
            }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testInsertInvalidDocument() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "foo", namespace: "bar", prefix: nil)
        
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) { error in
            XCTAssertEqual(error as? ArchiveError, .invalidDocument)
        }
    }
    
    func testInsertMissingFromJID() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("b@example.com", forAttribute: "to")
        
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) { error in
            XCTAssertEqual(error as? ArchiveError, .invalidDocument)
        }
    }
    
    func testInsertMissingToJID() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("b@example.com", forAttribute: "from")
        
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) { error in
            XCTAssertEqual(error as? ArchiveError, .invalidDocument)
        }
    }
    
    func testInsertAccountMismatch() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("a@example.com", forAttribute: "from")
        document.root.setValue("b@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) { error in
            XCTAssertEqual(error as? ArchiveError, .accountMismatch)
        }
    }
    
    func testUpdateMetadata() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        do {
            var metadata = Metadata()
            metadata.created = Date()
            var message = try archive.insert(document, metadata: metadata)
            XCTAssertNotNil(message)
            
            let error = NSError(domain: "MyError", code: 234, userInfo: ["some": "user info"])
            
            metadata.read = Date.distantFuture
            metadata.error = error
            metadata.isCarbonCopy = true
            message = try archive.update(metadata, for: message.messageID)
            
            XCTAssertNotNil(message.metadata.read)
            XCTAssertEqual(message.metadata.read, Date.distantFuture)
            
            XCTAssertNotNil(message.metadata.error)
            XCTAssertEqual(message.metadata.error as? NSError, error)
            
            XCTAssertTrue(message.metadata.isCarbonCopy)
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testUpdateDoesNotExsit() {
        guard let archive = self.archive else { return }
        
        let messageID = MessageID(
            uuid: UUID(),
            account: JID("a@example.com")!,
            counterpart: JID("b@example.com")!,
            direction: .outbound,
            type: .normal,
            originID: nil,
            stanzaID: nil
        )
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.update(metadata, for: messageID)) { error in
            XCTAssertEqual(error as? ArchiveError, .doesNotExist)
        }
    }
    
    func testGetMessage() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        do {
            var metadata = Metadata()
            metadata.created = Date()
            let message = try archive.insert(document, metadata: metadata)
            XCTAssertNotNil(message)
            
            let storedMessage = try archive.message(with: message.messageID)
            XCTAssertEqual(message.messageID.uuid, storedMessage.messageID.uuid)
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testGetDoesNotExsit() {
        guard let archive = self.archive else { return }
        
        let messageID = MessageID(
            uuid: UUID(),
            account: JID("a@example.com")!,
            counterpart: JID("b@example.com")!,
            direction: .outbound,
            type: .normal,
            originID: nil,
            stanzaID: nil
        )
        
        XCTAssertThrowsError(try archive.message(with: messageID)) { error in
            XCTAssertEqual(error as? ArchiveError, .doesNotExist)
        }
    }
    
    func testSortOrder() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        let now = Date()
        
        do {
            // without date should be on top
            for i in 0..<2 {
                document.root.setValue(String(1 - i), forAttribute: "id")
                let metadata = Metadata()
                let message = try archive.insert(document, metadata: metadata)
                XCTAssertNotNil(message)
            }
            
            // not transmitted should be before transmitted
            for i in 0..<10 {
                document.root.setValue(String(2 + i), forAttribute: "id")
                var metadata = Metadata()
                metadata.created = Date(timeInterval: 60.0 * Double(10 - i), since: now)
                let message = try archive.insert(document, metadata: metadata)
                XCTAssertNotNil(message)
            }
            
            for i in 0..<10 {
                document.root.setValue(String(12 + i), forAttribute: "id")
                var metadata = Metadata()
                metadata.transmitted = Date(timeInterval: 10000.0 + (60.0 * Double(10 - i)), since: now)
                let message = try archive.insert(document, metadata: metadata)
                XCTAssertNotNil(message)
            }
            
            let messages = try archive.all()
            for (idx, message) in messages.enumerated() {
                let document = try? archive.document(for: message.messageID)
                let id: String? = document?.root.value(forAttribute: "id") as? String
                let i = Int(id ?? "-1")
                XCTAssertEqual(idx, i)
            }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testConversation() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        
        do {
            for _ in 0..<10 {
                document.root.setValue("a@example.com", forAttribute: "to")
                let message = try archive.insert(document, metadata: Metadata())
                XCTAssertNotNil(message)
            }
            
            for _ in 0..<10 {
                document.root.setValue("b@example.com", forAttribute: "to")
                let message = try archive.insert(document, metadata: Metadata())
                XCTAssertNotNil(message)
            }
            
            for message in try archive.conversation(with: JID("b@example.com")!) {
                XCTAssertEqual(message.messageID.counterpart, JID("b@example.com")!)
            }
            
            for message in try archive.conversation(with: JID("a@example.com")!) {
                XCTAssertEqual(message.messageID.counterpart, JID("a@example.com")!)
            }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testRecent() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        
        do {
            let now = Date.distantFuture
            
            for i in 0..<10 {
                document.root.setValue("a@example.com", forAttribute: "to")
                var metadata = Metadata()
                metadata.transmitted = Date(timeInterval: (60.0 * Double(10 - i)), since: now)
                let message = try archive.insert(document, metadata: metadata)
                XCTAssertNotNil(message)
            }
            
            for i in 0..<10 {
                document.root.setValue("b@example.com", forAttribute: "to")
                var metadata = Metadata()
                metadata.transmitted = Date(timeInterval: (60.0 * Double(10 - i)), since: now)
                let message = try archive.insert(document, metadata: metadata)
                XCTAssertNotNil(message)
            }
            
            let recent = try archive.recent()
            
            XCTAssertEqual(recent.count, 2)
            XCTAssertEqual(recent[0].metadata.transmitted, Date(timeInterval: (60.0 * 10), since: now))
            XCTAssertEqual(recent[1].metadata.transmitted, Date(timeInterval: (60.0 * 10), since: now))
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func _testAccessPerformance() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        
        do {
            for _ in 0..<1000 {
                document.root.setValue("a@example.com", forAttribute: "to")
                let message = try archive.insert(document, metadata: Metadata())
                XCTAssertNotNil(message)
            }
            
            for _ in 0..<1000 {
                document.root.setValue("b@example.com", forAttribute: "to")
                let message = try archive.insert(document, metadata: Metadata())
                XCTAssertNotNil(message)
            }
            
            self.measure {
                do {
                    let messages = try archive.conversation(with: JID("b@example.com")!)
                    XCTAssertEqual(messages.count, 1000)
                } catch {
                    XCTFail("\(error)")
                }
            }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testDelete() {
        guard let archive = self.archive else { return }
        let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        do {
            var metadata = Metadata()
            metadata.created = Date()
            let message = try archive.insert(document, metadata: metadata)
            XCTAssertNotNil(message)
            
            try archive.delete(message.messageID)
            
            XCTAssertThrowsError(try archive.message(with: message.messageID)) { error in
                XCTAssertEqual(error as? ArchiveError, .doesNotExist)
            }
            
            XCTAssertThrowsError(try archive.document(for: message.messageID))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testPendingOutboundMessages() {
        guard
            let archive = self.archive
        else {
            return
        }
        
        do {
            let stanza = MessageStanza(from: JID("from@example.com")!, to: JID("juliet@example.com")!)
            let metadata = Metadata()
            let message = try archive.insert(stanza, metadata: metadata)
            XCTAssertTrue(try archive.pending().contains(message))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testPendingInboundMessages() {
        guard
            let archive = self.archive
        else {
            return
        }
        
        do {
            let stanza = MessageStanza(from: JID("juliet@example.com")!, to: JID("from@example.com")!)
            let metadata = Metadata()
            let message = try archive.insert(stanza, metadata: metadata)
            XCTAssertFalse(try archive.pending().contains(message))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testPendingMessagesError() {
        guard
            let archive = self.archive
        else {
            return
        }
        
        do {
            let stanza = MessageStanza(from: JID("from@example.com")!, to: JID("juliet@example.com")!)
            var metadata = Metadata()
            metadata.error = NSError(domain: "Test", code: 123, userInfo: nil)
            let message = try archive.insert(stanza, metadata: metadata)
            XCTAssertFalse(try archive.pending().contains(message))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testPendingMessagesTransmitted() {
        guard
            let archive = self.archive
        else {
            return
        }
        
        do {
            let stanza = MessageStanza(from: JID("from@example.com")!, to: JID("juliet@example.com")!)
            var metadata = Metadata()
            metadata.transmitted = Date()
            let message = try archive.insert(stanza, metadata: metadata)
            XCTAssertFalse(try archive.pending().contains(message))
        } catch {
            XCTFail("\(error)")
        }
    }
}
