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

class MessageArchiveRequestImplTests: TestCase {
    
    func testPerformFetchWithError() {
        let archive = TestArchive(account: JID("romeo@example.com")!)
        let delegate = Delegate()
        let iqHandler = IQHandler()
        iqHandler.handler = { document, timeout, complition in
            let error = NSError(domain: "MessageArchiveRequestTests", code: 1, userInfo: nil)
            complition?(nil, error)
        }

        let request = MessageArchiveRequestImpl(archive: archive)
        request.iqHandler = iqHandler
        request.delegate = delegate
        
        do {
            expectation(forNotification: "MessageArchiveRequestTests.didFailWith", object: delegate, handler: nil)
            let _ = try request.performFetch(before: nil, limit: 30)
            waitForExpectations(timeout: 1.0, handler: nil)
            
            guard
                case MessageArchiveRequestImpl.State.failed(_) = request.state
                else { XCTFail(); return }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testPerformFetch() {
        let archive = TestArchive(account: JID("romeo@example.com")!)
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
        
        let request = MessageArchiveRequestImpl(archive: archive)
        request.iqHandler = iqHandler
        request.delegate = delegate
        
        do {
            expectation(forNotification: "MessageArchiveRequestTests.didFinishWith", object: delegate, handler: nil)
            let _ = try request.performFetch(before: nil, limit: 30)
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
    
    enum TestError: Error {
        case notImplemented
    }
    
    class TestArchive: Archive {
        let account: JID
        init(account: JID) {
            self.account = account.bare()
        }
        
        func insert(_ document: PXDocument, metadata: Metadata) throws -> Message {
            let messageID = MessageID(
                uuid: UUID(),
                account: account,
                counterpart: JID("juliet@example.com")!,
                direction: .inbound,
                type: .normal,
                originID: nil,
                stanzaID: nil)
            return Message(messageID: messageID, metadata: metadata)
        }
        
        func update(_ metadata: Metadata, for messageID: MessageID) throws -> Message { throw TestError.notImplemented }
        func update(transmitted: Date?, error: TransmissionError?, for messageID: MessageID) throws -> Message { throw TestError.notImplemented }
        func delete(_ messageID: MessageID) throws {}
        func message(with messageID: MessageID) throws -> Message { throw TestError.notImplemented }
        func document(for messageID: MessageID) throws -> PXDocument { throw TestError.notImplemented }
        func all() throws -> [Message] { return [] }
        func recent() throws -> [Message] { return [] }
        func pending() throws -> [Message] { return [] }
        func conversation(with counterpart: JID) throws -> [Message] { return [] }
        func counterparts() throws -> [JID] { return [] }
    }
    
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
        func messageArchiveRequest(_ request: MessageArchiveRequest, didFinishWith result: MessageArchiveRequestResult) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MessageArchiveRequestTests.didFinishWith"), object: self)
        }
    }
}
