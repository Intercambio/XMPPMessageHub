//
//  MessageCarbonsReceivedFilterTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
@testable import XMPPMessageHub

class MessageCarbonsReceivedFilterTests: TestCase {
    
    func testFilter() {
        guard
            let document = PXDocument(named: "xep_0280_forwarded.xml", in: Bundle(for: MessageCarbonsReceivedFilterTests.self))
            else { XCTFail(); return }
        
        do {
            let filter = MessageCarbonsReceivedFilter()
            let result = try filter.apply(to: document, with: Metadata())
            
            let document = result.document
            XCTAssertEqual(document.root.value(forAttribute: "id") as? String, "456")
            XCTAssertEqual(document.root.value(forAttribute: "from") as? String, "juliet@capulet.example/balcony")
            XCTAssertEqual(document.root.value(forAttribute: "to") as? String, "romeo@montague.example/garden")
            
            let metadata = result.metadata
            XCTAssertTrue(metadata.forwarded)

        } catch {
            XCTFail("\(error)")
        }
    }
}
