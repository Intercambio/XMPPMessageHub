//
//  MessageCarbonsHandlerTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 11.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
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
            let response = IQStanza.makeDocumentWithIQStanza(from: request.to, to: request.from)
            let iq = response.root as! IQStanza
            iq.type = .result
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
