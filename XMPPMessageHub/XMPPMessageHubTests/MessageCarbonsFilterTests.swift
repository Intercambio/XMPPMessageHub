//
//  MessageCarbonsFilterTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
import XMPPFoundation
@testable import XMPPMessageHub

class MessageCarbonsFilterTests: TestCase {
    
    func testReceivedFilter() {
        guard
            let document = PXDocument(named: "xep_0280_received.xml", in: Bundle(for: MessageCarbonsFilterTests.self)),
            let stanza = document.root as? MessageStanza
            else { XCTFail(); return }
        
        do {
            let filter = MessageCarbonsFilter(direction: .received)
            let result = try filter.apply(to: stanza, with: Metadata(), userInfo: [:])
            
            let message = result?.message
            XCTAssertEqual(message?.value(forAttribute: "id") as? String, "456")
            XCTAssertEqual(message?.value(forAttribute: "from") as? String, "juliet@capulet.example/balcony")
            XCTAssertEqual(message?.value(forAttribute: "to") as? String, "romeo@montague.example/garden")
            
            let metadata = result?.metadata
            XCTAssertTrue(metadata?.isCarbonCopy ?? false)

        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testSentFilter() {
        guard
            let document = PXDocument(named: "xep_0280_sent.xml", in: Bundle(for: MessageCarbonsFilterTests.self)),
            let stanza = document.root as? MessageStanza
            else { XCTFail(); return }
        
        do {
            let filter = MessageCarbonsFilter(direction: .sent)
            let result = try filter.apply(to: stanza, with: Metadata(), userInfo: [:])
            
            let message = result?.message
            XCTAssertEqual(message?.value(forAttribute: "id") as? String, "456")
            XCTAssertEqual(message?.value(forAttribute: "from") as? String, "romeo@montague.example/home")
            XCTAssertEqual(message?.value(forAttribute: "to") as? String, "juliet@capulet.example/balcony")
            
            let metadata = result?.metadata
            XCTAssertTrue(metadata?.isCarbonCopy ?? false)
            
        } catch {
            XCTFail("\(error)")
        }
    }
}
