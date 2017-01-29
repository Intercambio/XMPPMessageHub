//
//  MessageArchiveManagementFilterTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 25.12.16.
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
}
