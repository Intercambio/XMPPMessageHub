//
//  MessageCarbonsHandlerTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 11.12.16.
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

class MessageCarbonsHandlerTests: HandlerTestCase {
    
    func testEnable() {
        guard
            let dispatcher = self.dispatcher
        else { XCTFail(); return }
        
        let handler = MessageCarbonsHandler(dispatcher: dispatcher)
        
        let delegate = Delegate()
        handler.delegate = delegate
        
        dispatcher.IQHandler = { request, _, complition in
            let iq = IQStanza(type: .result, from: request.to, to: request.from)
            complition?(iq, nil)
        }
        
        expectation(forNotification: "MessageCarbonsHandlerTests.didEnable", object: delegate, handler: nil)
        dispatcher.connect(JID("romeo@examle.com")!, resumed: false, features: [])
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    // MARK: - Helper
    
    class Delegate: MessageCarbonsHandlerDelegate {
        func messageCarbonsHandler(_: MessageCarbonsHandler, didEnableFor _: JID) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageCarbonsHandlerTests.didEnable"), object: self)
        }
        func messageCarbonsHandler(_: MessageCarbonsHandler, failedToEnableFor _: JID, wirth _: Error) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageCarbonsHandlerTests.failed"), object: self)
        }
    }
}
