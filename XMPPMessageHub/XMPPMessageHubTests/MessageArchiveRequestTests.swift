//
//  MessageArchiveRequestTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 22.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
import XMPPFoundation
import ISO8601
@testable import XMPPMessageHub

class MessageArchiveRequestTests: TestCase {
    
    func testPerformFetchWithError() {
        let delegate = Delegate()
        let iqHandler = IQHandler()
        iqHandler.handler = { document, timeout, complition in
            let error = NSError(domain: "MessageArchiveRequestTests", code: 1, userInfo: nil)
            complition?(nil, error)
        }

        let request = MessageArchiveRequest(account: JID("romeo@example.com")!)
        request.iqHandler = iqHandler
        request.delegate = delegate
        
        do {
            expectation(forNotification: "MessageArchiveRequestTests.didFailWith", object: delegate, handler: nil)
            try request.performFetch(before: nil, limit: 30)
            waitForExpectations(timeout: 1.0, handler: nil)
            
            guard
                case MessageArchiveRequest.State.failed(_) = request.state
                else { XCTFail(); return }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testFilter() {
        guard
            let document = PXDocument(named: "xep_0313_message.xml", in: Bundle(for: MessageCarbonsFilterTests.self))
            else { XCTFail(); return }
        
        let namespaces = ["x":"urn:xmpp:mam:1"]
        let resultElement = document.root.nodes(forXPath: "./x:result", usingNamespaces: namespaces).first as? PXElement
        
        let request = MessageArchiveRequest(account: JID("romeo@example.com")!)
        try? request.performFetch(before: nil, limit: 10)
        
        resultElement?.setValue(request.queryID, forAttribute: "queryid")
        
        let dateFormatter = ISO8601.ISO8601DateFormatter()
        let timestamp = dateFormatter.date(from: "2010-07-10T23:08:25Z")
        
        do {
            let result = try request.apply(to: document, with: Metadata(), userInfo: [:])
            
            let document = result.document
            XCTAssertEqual(document.root.value(forAttribute: "from") as? String, "witch@shakespeare.lit")
            XCTAssertEqual(document.root.value(forAttribute: "to") as? String, "macbeth@shakespeare.lit")
            
            let metadata = result.metadata
            XCTAssertEqual(metadata.created, timestamp)
            XCTAssertEqual(metadata.transmitted, timestamp)
            
            let userInfo = result.userInfo
            XCTAssertEqual(userInfo[MessageArchvieIDKey] as? String, "28482-98726-73623")
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testPerformFetch() {
        let delegate = Delegate()
        let iqHandler = IQHandler()
        iqHandler.handler = { document, timeout, complition in
            if let request = document.root as? IQStanza {
                let response = IQStanza.makeDocumentWithIQStanza(from: request.to, to: request.from)
                let iq = response.root as! IQStanza
                iq.type = .result
                
                let query = iq.add(withName: "fin", namespace: "urn:xmpp:mam:1", content: nil)!
                let rsm = query.add(withName: "set", namespace: "http://jabber.org/protocol/rsm", content: nil) as! XMPPResultSet
                rsm.first = "123"
                rsm.last = "abc"
                rsm.count = 10
                
                complition?(response, nil)
            } else {
                let error = NSError(domain: "MessageCarbonsDispatchHandlerTests", code: 1, userInfo: nil)
                complition?(nil, error)
            }
        }
        
        let request = MessageArchiveRequest(account: JID("romeo@example.com")!)
        request.iqHandler = iqHandler
        request.delegate = delegate
        
        do {
            expectation(forNotification: "MessageArchiveRequestTests.didFinishWith", object: delegate, handler: nil)
            try request.performFetch(before: nil, limit: 30)
            waitForExpectations(timeout: 1.0, handler: nil)
            
            switch request.state {
            case .finished(let result):
                XCTAssertEqual(result.first, "123")
                XCTAssertEqual(result.last, "abc")
                XCTAssertTrue(result.stable)
                XCTAssertFalse(result.complete)
            default:
                XCTFail("Unexpected state \(request.state)")
            }
            
        } catch {
            XCTFail("\(error)")
        }
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
    
    class Delegate: MessageArchiveRequestDelegate {
        func messageArchiveRequest(_ request: MessageArchiveRequest, didFailWith error: Error) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageArchiveRequestTests.didFailWith"), object: self)
        }
        func messageArchiveRequest(_ request: MessageArchiveRequest, didFinishWith result: MessageArchiveResult) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageArchiveRequestTests.didFinishWith"), object: self)
        }
    }
}
