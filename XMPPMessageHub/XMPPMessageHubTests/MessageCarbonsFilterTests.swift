//
//  MessageCarbonsFilterTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
@testable import XMPPMessageHub

class MessageCarbonsFilterTests: TestCase {
    
    func testReceivedFilter() {
        guard
            let document = PXDocument(named: "xep_0280_received.xml", in: Bundle(for: MessageCarbonsFilterTests.self))
            else { XCTFail(); return }
        
        do {
            let filter = MessageCarbonsFilter(direction: .received)
            let result = try filter.apply(to: document, with: Metadata(), userInfo: [:])
            
            let document = result.document
            XCTAssertEqual(document.root.value(forAttribute: "id") as? String, "456")
            XCTAssertEqual(document.root.value(forAttribute: "from") as? String, "juliet@capulet.example/balcony")
            XCTAssertEqual(document.root.value(forAttribute: "to") as? String, "romeo@montague.example/garden")
            
            let metadata = result.metadata
            XCTAssertTrue(metadata.isCarbonCopy)

        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testSentFilter() {
        guard
            let document = PXDocument(named: "xep_0280_sent.xml", in: Bundle(for: MessageCarbonsFilterTests.self))
            else { XCTFail(); return }
        
        do {
            let filter = MessageCarbonsFilter(direction: .sent)
            let result = try filter.apply(to: document, with: Metadata(), userInfo: [:])
            
            let document = result.document
            XCTAssertEqual(document.root.value(forAttribute: "id") as? String, "456")
            XCTAssertEqual(document.root.value(forAttribute: "from") as? String, "romeo@montague.example/home")
            XCTAssertEqual(document.root.value(forAttribute: "to") as? String, "juliet@capulet.example/balcony")
            
            let metadata = result.metadata
            XCTAssertTrue(metadata.isCarbonCopy)
            
        } catch {
            XCTFail("\(error)")
        }
    }
}
