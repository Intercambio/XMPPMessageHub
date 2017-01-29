//
//  OutboundMessageHandlerTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 22.01.17.
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

class OutboundMessageHandlerTests: HandlerTestCase {
    
    func testDispatchMessage() {
        guard
            let dispatcher = self.dispatcher,
            let archvieManager = self.archiveManager,
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
            
            let handler = OutboundMessageHandler(dispatcher: dispatcher, archvieManager: archvieManager)
            
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
            let archvieManager = self.archiveManager,
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
            
            let handler = OutboundMessageHandler(dispatcher: dispatcher, archvieManager: archvieManager)
            
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
    
    func testResendPendingMessages() {
        guard
            let dispatcher = self.dispatcher,
            let archvieManager = self.archiveManager,
            let account = JID("romeo@example.com"),
            let archive = archive(for: account)
        else {
            XCTFail()
            return
        }
        
        do {
            let stanza = MessageStanza(from: JID("romeo@example.com")!, to: JID("juliet@example.com")!)
            let metadata = Metadata()
            _ = try archive.insert(stanza, metadata: metadata)
            
            let handler = OutboundMessageHandler(dispatcher: dispatcher, archvieManager: archvieManager)
            
            let expectation = self.expectation(description: "Dispatch Message")
            dispatcher.messageHandler = { _, comletion in
                comletion?(nil)
                expectation.fulfill()
            }
            
            handler.didConnect(JID("romeo@example.com")!, resumed: false, features: nil)
            
            waitForExpectations(timeout: 1.0, handler: nil)
            
        } catch {
            XCTFail("\(error)")
        }
    }
}
