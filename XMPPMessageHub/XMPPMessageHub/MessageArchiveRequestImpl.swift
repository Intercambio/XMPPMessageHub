//
//  MessageArchiveRequestImpl.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 25.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation
import ISO8601

class MessageArchiveRequestImpl: MessageArchiveRequest, MessageFilter, MessageArchiveRequestHandler {
    
    enum State {
        case intitalized
        case fetching(pending: [MessageArchvieID], messages: [MessageArchvieID:MessageID])
        case waiting(pending: [MessageArchvieID], result: MessageArchiveRequestResult)
        case finished(result: MessageArchiveRequestResult)
        case failed(error: Error)
    }
    
    weak var iqHandler: IQHandler?
    weak var delegate: MessageArchiveRequestDelegate?
    
    let account: JID
    let timeout: TimeInterval
    let queryID: String
    
    private(set) var state: State = .intitalized {
        didSet {
            if case .finished(let result) = state {
                delegate?.messageArchiveRequest(self, didFinishWith: result)
            } else if case .failed(let error) = state {
                delegate?.messageArchiveRequest(self, didFailWith: error)
            }
        }
    }
    
    private let dateFormatter: ISO8601.ISO8601DateFormatter = ISO8601DateFormatter()
    private let queue: DispatchQueue
    required init(account: JID, timeout: TimeInterval = 120.0) {
        self.account = account
        self.timeout = timeout
        self.queryID = UUID().uuidString.lowercased()
        queue = DispatchQueue(
            label: "MessageArchiveRequest",
            attributes: [])
    }
    
    func performFetch(before: MessageArchvieID?, limit: Int) throws -> (inboundFilter: MessageFilter, handler: MessageArchiveRequestHandler) {
        try queue.sync {
            guard
                case .intitalized = self.state
                else { throw MessageArchiveRequestError.alreadyRunning }
            let request = self.makeRequest(before: before, limit: limit)
            self.iqHandler?.handleIQRequest(request, timeout: self.timeout) { [weak self] response, error in
                guard
                    let this = self
                    else { return }
                this.queue.async {
                    if let response = response {
                        this.handleResponse(response)
                    } else {
                        this.state = .failed(error: error ?? MessageArchiveRequestError.internalError)
                    }
                }
            }
            self.state = .fetching(pending: [], messages: [:])
        }
        return (inboundFilter: self, handler: self)
    }
    
    private func handleResponse(_ document: PXDocument) {
        let namespaces = ["x": "urn:xmpp:mam:1"]
        guard
            let fin = document.root.nodes(forXPath: "./x:fin", usingNamespaces: namespaces).first as? PXElement,
            let rsm = fin.resultSet,
            let first = rsm.first,
            let last = rsm.last
            else {
                self.state = .failed(error: MessageArchiveRequestError.unexpectedResponse)
                return
        }
        
        guard
            case .fetching(let pending, let messages) = self.state
            else { return }
        
        let stable = Bool(fin.value(forAttribute: "stable") as? String ?? "") ?? true
        let complete = Bool(fin.value(forAttribute: "complete") as? String ?? "") ?? false
        
        let result = MessageArchiveRequestResult(
            first: first,
            last: last,
            stable: stable,
            complete: complete,
            messages: messages)
        
        if pending.count == 0 {
            self.state = .finished(result: result)
        } else {
            self.state = .waiting(pending: pending, result: result)
        }
    }
    
    // MARK: - MessageFilter
    
    func apply(to document: PXDocument, with metadata: Metadata, userInfo: [AnyHashable:Any]) throws -> MessageFilter.Result {
        return try queue.sync {
            
            let namespaces = [
                "mam": "urn:xmpp:mam:1",
                "forward": "urn:xmpp:forward:0",
                "xmpp":"jabber:client",
                "delay":"urn:xmpp:delay"]
            
            guard
                case .fetching(var pending, let messages) = self.state
                else {
                    return (document: document, metadata: metadata, userInfo: userInfo)
            }
            
            guard
                let message = document.root as? MessageStanza,
                let result = message.nodes(forXPath: "./mam:result", usingNamespaces: namespaces).first as? PXElement,
                result.value(forAttribute: "queryid") as? String == self.queryID
                else {
                    return (document: document, metadata: metadata, userInfo: userInfo)
            }
            
            guard
                let archiveID = result.value(forAttribute: "id") as? String,
                let delayElement = result.nodes(forXPath: "./forward:forwarded/delay:delay", usingNamespaces: namespaces).first as? PXElement,
                let timestampString = delayElement.value(forAttribute: "stamp") as? String,
                let timestamp = self.dateFormatter.date(from: timestampString),
                let originalMessage = result.nodes(forXPath: "./forward:forwarded/xmpp:message", usingNamespaces: namespaces).first as? MessageStanza
                else {
                    throw MessageArchiveRequestError.unexpectedResponse
            }
            
            var newMetadata = metadata
            newMetadata.created = timestamp
            newMetadata.transmitted = timestamp
            
            var newUserInfo = userInfo
            newUserInfo[MessageArchvieIDKey] = archiveID
            
            pending.append(archiveID)
            
            self.state = .fetching(pending: pending, messages: messages)
            
            return (document: PXDocument(element: originalMessage)!,
                    metadata: newMetadata,
                    userInfo: newUserInfo)
        }
    }
    
    // MARK: - MessageArchiveRequestHandler
    
    func savedMessage(with messageID: MessageID, userInfo: [AnyHashable:Any]) {
        queue.async {
            guard
                let archiveID = userInfo[MessageArchvieIDKey] as? String
                else { return }
            
            if case .fetching(var pending, var messages) = self.state {
                if let idx = pending.index(of: archiveID) {
                    pending.remove(at: idx)
                    messages[archiveID] = messageID
                    self.state = .fetching(pending: pending, messages: messages)
                }
            }
            
            if case .waiting(var pending, var result) = self.state {
                if let idx = pending.index(of: archiveID) {
                    pending.remove(at: idx)
                    result.messages[archiveID] = messageID
                    
                    if pending.count == 0 {
                        self.state = .finished(result: result)
                    } else {
                        self.state = .waiting(pending: pending, result: result)
                    }
                }
            }
        }
    }
    
    func failedSavingMessage(with error:Error, userInfo: [AnyHashable:Any]) {
        queue.async {
            guard
                let archiveID = userInfo[MessageArchvieIDKey] as? String
                else { return }
            
            let existingMessageID = (error as? MessageAlreadyExist)?.existingMessageID
            
            if case .fetching(var pending, var messages) = self.state {
                if let idx = pending.index(of: archiveID) {
                    pending.remove(at: idx)
                    if let messageID = existingMessageID {
                        messages[archiveID] = messageID
                        self.state = .fetching(pending: pending, messages: messages)
                    } else {
                        self.state = .failed(error: error)
                    }
                }
            }
            
            if case .waiting(var pending, var result) = self.state {
                if let idx = pending.index(of: archiveID) {
                    pending.remove(at: idx)
                    if let messageID = existingMessageID {
                        result.messages[archiveID] = messageID
                        if pending.count == 0 {
                            self.state = .finished(result: result)
                        } else {
                            self.state = .waiting(pending: pending, result: result)
                        }
                    } else {
                        self.state = .failed(error: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper
    
    private func makeRequest(before: MessageArchvieID?, limit: Int) -> PXDocument {
        let document = IQStanza.makeDocumentWithIQStanza(from: nil, to: account)
        let iq = document.root as! IQStanza
        iq.type = .set
        let query = iq.add(withName: "query", namespace: "urn:xmpp:mam:1", content: nil)!
        query.setValue(queryID, forAttribute: "queryid")
        query.addResultSet(withMax: 20, before: before ?? "")
        return document
    }
}
