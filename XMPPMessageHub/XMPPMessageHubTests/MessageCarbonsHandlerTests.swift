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

class MessageCarbonsHandlerTests: TestCase {
    
    func testEnable() {

        let dispatcher = TestDispatcher()
        let delegate = Delegate()
        
        let handler = MessageCarbonsHandler(dispatcher: dispatcher)
        handler.delegate = delegate
        
        dispatcher.handler = { request, timeout, complition in
            let response = IQStanza.makeDocumentWithIQStanza(from: request.to, to: request.from)
            let iq = response.root as! IQStanza
            iq.type = .result
            complition?(iq, nil)
        }
    
        expectation(forNotification: "MessageCarbonsHandlerTests.didEnable", object: delegate, handler: nil)
        handler.didConnect(JID("romeo@examle.com")!, resumed: false)
        waitForExpectations(timeout: 1.0, handler: nil)
    }

    // MARK: - Helper
    
    class Delegate: MessageCarbonsHandlerDelegate {
        func messageCarbonsHandler(_ handler: MessageCarbonsHandler, didEnableFor account: JID) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageCarbonsHandlerTests.didEnable"), object: self)
        }
        func messageCarbonsHandler(_ handler: MessageCarbonsHandler, failedToEnableFor account: JID, wirth error: Error) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageCarbonsHandlerTests.failed"), object: self)
        }
    }
    
    class TestDispatcher: Dispatcher {
        
        typealias Completion = ((IQStanza?, Error?) -> Void)
        var handler: ((IQStanza, TimeInterval, Completion?) -> Void)?
        
        let handlers: NSHashTable = NSHashTable<Handler>.weakObjects()
        
        func add(_ handler: Handler) {
            add(handler, withIQQueryQNames: nil)
        }
        
        func add(_ handler: Handler, withIQQueryQNames queryQNames: [PXQName]?) {
            handlers.add(handler)
        }
        
        func remove(_ handler: Handler) {
            handlers.remove(handler)
        }
        
        public func didConnect(_ JID: JID, resumed: Bool) {}
        public func didDisconnect(_ JID: JID) {}
        public func handleMessage(_ stanza: MessageStanza, completion: ((Error?) -> Void)? = nil) {}
        public func handlePresence(_ stanza: PresenceStanza, completion: ((Error?) -> Swift.Void)? = nil) {}
        
        public func handleIQRequest(_ request: IQStanza,
                                    timeout: TimeInterval,
                                    completion: ((IQStanza?, Error?) -> Swift.Void)? = nil) {
            handler?(request, timeout, completion)
        }
    }
}
