//
//  MessageArchiveRequestImplTests.swift
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

class MessageArchiveRequestImplTests: HandlerTestCase {
    
    func testPerformFetchWithError() {
        guard
            let archive = self.archive(for: JID("romeo@example.com")!),
            let dispatcher = self.dispatcher
        else { return }
        
        dispatcher.IQHandler = { _, _, complition in
            let error = NSError(domain: "MessageArchiveRequestTests", code: 1, userInfo: nil)
            complition?(nil, error)
        }
        
        let request = MessageArchiveRequestImpl(dispatcher: dispatcher, archive: archive)
        let delegate = Delegate()
        request.delegate = delegate
        
        do {
            expectation(forNotification: "MessageArchiveRequestTests.didFailWith", object: delegate, handler: nil)
            _ = try request.performFetch(before: nil, limit: 30)
            waitForExpectations(timeout: 1.0, handler: nil)
            
            guard
                case MessageArchiveRequestImpl.State.failed = request.state
            else { XCTFail(); return }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testPerformFetch() {
        guard
            let archive = self.archive(for: JID("romeo@example.com")!),
            let dispatcher = self.dispatcher
        else { return }
        
        dispatcher.IQHandler = { request, _, complition in
            
            XCTAssertEqual(request.from, JID("romeo@example.com")!)
            
            let iq = IQStanza(type: .result, from: request.to, to: request.from)
            let query = iq.add(withName: "fin", namespace: "urn:xmpp:mam:1", content: nil)!
            let rsm = query.add(withName: "set", namespace: "http://jabber.org/protocol/rsm", content: nil) as! XMPPResultSet
            rsm.first = "123"
            rsm.last = "abc"
            rsm.count = 10
            
            complition?(iq, nil)
        }
        
        let request = MessageArchiveRequestImpl(dispatcher: dispatcher, archive: archive)
        let delegate = Delegate()
        request.delegate = delegate
        
        do {
            expectation(forNotification: "MessageArchiveRequestTests.didFinishWith", object: delegate, handler: nil)
            _ = try request.performFetch(before: nil, limit: 30)
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
    
    class Delegate: MessageArchiveRequestDelegate {
        func messageArchiveRequest(_: MessageArchiveRequest, didFailWith _: Error) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageArchiveRequestTests.didFailWith"), object: self)
        }
        func messageArchiveRequest(_: MessageArchiveRequest, didFinishWith _: MAMIndexPartition) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageArchiveRequestTests.didFinishWith"), object: self)
        }
    }
}
