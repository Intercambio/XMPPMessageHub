//
//  MessageCarbonsDispatchHandlerTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 11.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
import XMPPFoundation
@testable import XMPPMessageHub

class MessageCarbonsDispatchHandlerTests: TestCase {
    
    func testEnable() {

        let delegate = Delegate()
        let iqHandler = IQHandler()
        
        let handler = MessageCarbonsDispatchHandler()
        handler.delegate = delegate
        handler.iqHandler = iqHandler
        
        iqHandler.handler = { document, timeout, complition in
            if let request = document.root as? IQStanza {
                let response = IQStanza.makeDocumentWithIQStanza(from: request.to, to: request.from)
                let iq = response.root as! IQStanza
                iq.type = .result
                complition?(response, nil)
            } else {
                let error = NSError(domain: "MessageCarbonsDispatchHandlerTests", code: 1, userInfo: nil)
                complition?(nil, error)
            }
        }
    
        expectation(forNotification: "MessageCarbonsDispatchHandlerTests.didEnable", object: delegate, handler: nil)
        handler.didConnect(JID("romeo@examle.com")!, resumed: false)
        waitForExpectations(timeout: 1.0, handler: nil)
    }

    // MARK: - Helper
    
    class IQHandler: NSObject, XMPPFoundation.IQHandler {
        
        typealias Completion = ((PXDocument?, Error?) -> Void)
        var handler: ((PXDocument, TimeInterval, Completion?) -> Void)?
        
        public func handleIQRequest(_ document: PXDocument,
                                    timeout: TimeInterval,
                                    completion: ((PXDocument?, Error?) -> Swift.Void)? = nil) {
            handler?(document, timeout, completion)
        }
    }
    
    class Delegate: MessageCarbonsDispatchHandlerDelegate {
        func messageCarbonsDispatchHandler(_ handler: MessageCarbonsDispatchHandler, didEnableFor account: JID) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageCarbonsDispatchHandlerTests.didEnable"), object: self)
        }
        func messageCarbonsDispatchHandler(_ handler: MessageCarbonsDispatchHandler, failedToEnableFor account: JID, wirth error: Error) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageCarbonsDispatchHandlerTests.failed"), object: self)
        }
    }
}
