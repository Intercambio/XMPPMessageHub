//
//  MessageCarbonsFilterTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
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
