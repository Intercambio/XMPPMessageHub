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
import CoreXMPP
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
            let hub = self.hub,
            let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
            else { XCTFail(); return }
        
        // Dispatch the message
        
        document.root.setValue("juliet@example.com", forAttribute: "from")
        document.root.setValue("romeo@example.com", forAttribute: "to")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("456", forAttribute: "id")
        
        expectation(forNotification: Hub.DidAddMessageNotification.rawValue, object: hub, handler: nil)
        
        let dispatchExp = expectation(description: "Message Handled")
        hub.handleMessage(document) { error in
            XCTAssertNil(error)
            dispatchExp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Verify that the message is in the archvie
        
        let getArchiveExp = expectation(description: "Get Archive")
        hub.archive(for: JID("romeo@example.com")!, create: false) {
            archive, error in
            XCTAssertNil(error)
            XCTAssertNotNil(archive)
            DispatchQueue.main.async {
                do {
                    if let archive = archive {
                        let messages = try archive.all()
                        XCTAssertEqual(messages.count, 1)
                        
                        let message = messages[0]
                        let document = try archive.document(for: message.messageID)
                        XCTAssertNotNil(document)
                        XCTAssertEqual(document.root.value(forAttribute: "id") as? String, "456")
                    }
                } catch {
                    XCTFail("\(error)")
                }
                getArchiveExp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testSendMessage() {
        guard
            let hub = self.hub,
            let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil)
            else { XCTFail(); return }
        
        document.root.setValue("juliet@example.com", forAttribute: "to")
        document.root.setValue("romeo@example.com", forAttribute: "from")
        document.root.setValue("chat", forAttribute: "type")
        document.root.setValue("456", forAttribute: "id")
        
        let dispatcher = Dispatcher()
        hub.messageHandler = dispatcher
        
        expectation(forNotification: Hub.DidUpdateMessageNotification.rawValue, object: hub, handler: nil)
        
        let getArchiveExp = expectation(description: "Get Archive")
        hub.archive(for: JID("romeo@example.com")!, create: true) {
            archive, error in
            XCTAssertNil(error)
            XCTAssertNotNil(archive)
            
            do {
                if let archive = archive {
                    let _ = try archive.insert(document, metadata: Metadata())
                }
            } catch {
                XCTFail("\(error)")
            }
            
            getArchiveExp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        let verify = expectation(description: "Verify Archive")
        hub.archive(for: JID("romeo@example.com")!, create: false) {
            archive, error in
            XCTAssertNil(error)
            XCTAssertNotNil(archive)
            
            do {
                if let archive = archive {
                    let messages = try archive.all()
                    XCTAssertEqual(messages.count, 1)
                    
                    let message = messages[0]
                    XCTAssertNotNil(message.metadata.transmitted)
                }
            } catch {
                XCTFail("\(error)")
            }
            verify.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    class Dispatcher: NSObject, MessageHandler {
        func handleMessage(_ document: PXDocument, completion: ((Error?) -> Void)? = nil) {
            completion?(nil)
        }
    }
}
