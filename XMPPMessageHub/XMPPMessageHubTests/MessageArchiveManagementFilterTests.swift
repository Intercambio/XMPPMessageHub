//
//  MessageArchiveManagementFilterTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 25.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
import XMPPFoundation
import ISO8601
@testable import XMPPMessageHub

class MessageArchiveManagementResultFilterTests: TestCase {
    
    func test() {
        
        guard
            let document = PXDocument(named: "xep_0313_message.xml", in: Bundle(for: MessageCarbonsFilterTests.self)),
            let message = document.root as? MessageStanza
        else { XCTFail(); return }
        
        let dateFormatter = ISO8601.ISO8601DateFormatter()
        let timestamp = dateFormatter.date(from: "2010-07-10T23:08:25Z")
        
        do {
            
            let filter = MessageArchiveManagementFilter()
            let result = try filter.apply(to: message, with: Metadata(), userInfo: [:])
            
            let stanza = result?.message
            XCTAssertEqual(stanza?.value(forAttribute: "from") as? String, "witch@shakespeare.lit")
            XCTAssertEqual(stanza?.value(forAttribute: "to") as? String, "macbeth@shakespeare.lit")
            
            let metadata = result?.metadata
            XCTAssertEqual(metadata?.created, timestamp)
            XCTAssertEqual(metadata?.transmitted, timestamp)
            
            let userInfo = result?.userInfo
            XCTAssertEqual(userInfo?[MessageArchvieIDKey] as? String, "28482-98726-73623")
            XCTAssertEqual(userInfo?[MessageArchvieQueryIDKey] as? String, "f27")
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testNamespaceWorkaround() {
        
        guard
            let document = PXDocument(named: "xep_0313_message_invalid_ns.xml", in: Bundle(for: MessageCarbonsFilterTests.self)),
            let message = document.root as? MessageStanza
        else { XCTFail(); return }
        
        let dateFormatter = ISO8601.ISO8601DateFormatter()
        let timestamp = dateFormatter.date(from: "2010-07-10T23:08:25Z")
        
        do {
            
            let filter = MessageArchiveManagementFilter()
            let result = try filter.apply(to: message, with: Metadata(), userInfo: [:])
            
            let stanza = result?.message
            XCTAssertEqual(stanza?.value(forAttribute: "from") as? String, "witch@shakespeare.lit")
            XCTAssertEqual(stanza?.value(forAttribute: "to") as? String, "macbeth@shakespeare.lit")
            
            let metadata = result?.metadata
            XCTAssertEqual(metadata?.created, timestamp)
            XCTAssertEqual(metadata?.transmitted, timestamp)
            
            let userInfo = result?.userInfo
            XCTAssertEqual(userInfo?[MessageArchvieIDKey] as? String, "28482-98726-73623")
            XCTAssertEqual(userInfo?[MessageArchvieQueryIDKey] as? String, "f27")
            
        } catch {
            XCTFail("\(error)")
        }
    }
}
