//
//  ArchiveTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 20.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
import CoreXMPP
@testable import XMPPMessageHub

class ArchiveTests: TestCase {

    var archive: Archive?
    
    override func setUp() {
        super.setUp()
        
        guard let directory = self.directory else { return }
        
        let archive = Archive(directory: directory, account: JID("from@example.com")!)
        
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
        XCTAssertEqual(version, Archive.Setup.version)
    }
    
    func testInsert() {
        guard let archive = self.archive else { return }
        guard let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil) else { return }
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        do {
            var metadata = Metadata()
            metadata.created = Date()
            let message = try archive.insert(document, metadata: metadata)
            XCTAssertNotNil(message)
        
            let document = try archive.document(for: message.messageID)
            XCTAssertNotNil(document)
            XCTAssertEqual(document.root.value(forAttribute: "id") as? String, "123")
            
            try archive.enumerateAll({ (message, idx, stop) in
                print("\(message)")
            })
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testInsertInvalidDocument() {
        guard let archive = self.archive else { return }
        guard let document = PXDocument(elementName: "foo", namespace: "bar", prefix: nil) else { return }
        
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) {error in
            XCTAssertEqual(error as? ArchiveError, .invalidDocument)
        }
    }
    
    func testInsertMissingFromJID() {
        guard let archive = self.archive else { return }
        guard let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil) else { return }
        
        document.root.setValue("b@example.com", forAttribute: "to")
        
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) {error in
            XCTAssertEqual(error as? ArchiveError, .invalidDocument)
        }
    }
    
    func testInsertMissingToJID() {
        guard let archive = self.archive else { return }
        guard let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil) else { return }
        
        document.root.setValue("b@example.com", forAttribute: "from")
        
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) {error in
            XCTAssertEqual(error as? ArchiveError, .invalidDocument)
        }
    }
    
    func testInsertAccountMismatch() {
        guard let archive = self.archive else { return }
        guard let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil) else { return }
        
        document.root.setValue("a@example.com", forAttribute: "from")
        document.root.setValue("b@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.insert(document, metadata: metadata)) {error in
            XCTAssertEqual(error as? ArchiveError, .accountMismatch)
        }
    }
    
    func testUpdateMetadata() {
        guard let archive = self.archive else { return }
        guard let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil) else { return }
        
        document.root.setValue("from@example.com", forAttribute: "from")
        document.root.setValue("to@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("123", forAttribute: "id")
        
        do {
            var metadata = Metadata()
            metadata.created = Date()
            var message = try archive.insert(document, metadata: metadata)
            XCTAssertNotNil(message)
            
            metadata.read = Date.distantFuture
            message = try archive.update(metadata, for: message.messageID)
            
            XCTAssertEqual(message.metadata.read, Date.distantFuture)
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testUpdateDoesNotExsit() {
        guard let archive = self.archive else { return }
        
        let messageID = MessageID(uuid: UUID(),
                                  account:JID("a@example.com")!,
                                  counterpart: JID("b@example.com")!,
                                  direction: .outbound,
                                  type: .normal)
        let metadata = Metadata()
        XCTAssertThrowsError(try archive.update(metadata, for: messageID)) {error in
            XCTAssertEqual(error as? ArchiveError, .doesNotExist)
        }
    }
    
    func testGetMessage() {
        guard let archive = self.archive else { return }
        guard let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil) else { return }
        
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
        
        let messageID = MessageID(uuid: UUID(),
                                  account:JID("a@example.com")!,
                                  counterpart: JID("b@example.com")!,
                                  direction: .outbound,
                                  type: .normal)
        
        XCTAssertThrowsError(try archive.message(with: messageID)) {error in
            XCTAssertEqual(error as? ArchiveError, .doesNotExist)
        }
    }
}
