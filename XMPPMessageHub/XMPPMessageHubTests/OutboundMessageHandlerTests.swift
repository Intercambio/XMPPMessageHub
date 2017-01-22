//
//  OutboundMessageHandlerTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 22.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
import XMPPFoundation
@testable import XMPPMessageHub

class OutboundMessageHandlerTests: HandlerTestCase {
    
    func testDispatchMessage() {
        guard
            let dispatcher = self.dispatcher,
            let account = JID("romeo@example.com"),
            let archive = archive(for: account)
        else {
            XCTFail()
            return
        }
        
        do {
            
            let stanza = MessageStanza(from: JID("romeo@example.com")!, to: JID("juliet@example.com")!)
            let metadata = Metadata()
            let message = try archive.insert(stanza, metadata: metadata)
            let document = try archive.document(for: message.messageID)
            
            let handler = OutboundMessageHandler(dispatcher: dispatcher)
            
            let expectation = self.expectation(description: "Dispatch Message")
            dispatcher.messageHandler = { _, comletion in
                comletion?(nil)
                expectation.fulfill()
            }
            
            handler.send(message, with: document, in: archive)
            
            waitForExpectations(timeout: 1.0, handler: nil)
            
            let updatedMessage = try archive.message(with: message.messageID)
            XCTAssertNotNil(updatedMessage.metadata.transmitted)
            XCTAssertNil(updatedMessage.metadata.error)
            
        } catch {
            XCTFail("\(error)")
        }
        
    }
    
    func testNoRouteError() {
        guard
            let dispatcher = self.dispatcher,
            let account = JID("romeo@example.com"),
            let archive = archive(for: account)
        else {
            XCTFail()
            return
        }
        
        do {
            
            let stanza = MessageStanza(from: JID("romeo@example.com")!, to: JID("juliet@example.com")!)
            let metadata = Metadata()
            let message = try archive.insert(stanza, metadata: metadata)
            let document = try archive.document(for: message.messageID)
            
            let handler = OutboundMessageHandler(dispatcher: dispatcher)
            
            let expectation = self.expectation(description: "Dispatch Message")
            dispatcher.messageHandler = { _, comletion in
                let error = NSError(
                    domain: DispatcherErrorDomain,
                    code: DispatcherErrorCode.noRoute.rawValue,
                    userInfo: nil
                )
                comletion?(error)
                expectation.fulfill()
            }
            
            handler.send(message, with: document, in: archive)
            
            waitForExpectations(timeout: 1.0, handler: nil)
            
            let updatedMessage = try archive.message(with: message.messageID)
            XCTAssertNil(updatedMessage.metadata.transmitted)
            XCTAssertNil(updatedMessage.metadata.error)
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
}
