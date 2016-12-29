//
//  MessageArchiveRequestImpl.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 25.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation

class MessageArchiveRequestImpl: NSObject, MessageArchiveRequest, MessageHandler {
    
    enum State {
        case intitalized
        case fetching(messages: [MessageArchvieID:MessageID])
        case finished(result: MessageArchiveRequestResult)
        case failed(error: Error)
    }
    
    weak var iqHandler: IQHandler?
    weak var delegate: MessageArchiveRequestDelegate?
    
    let archive: Archive
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
    
    private let filter: MessageFilter = MessageArchiveManagementFilter()
    private let queue: DispatchQueue
    required init(archive: Archive) {
        self.archive = archive
        self.queryID = UUID().uuidString.lowercased()
        queue = DispatchQueue(
            label: "MessageArchiveRequestImpl",
            attributes: [])
    }
    
    func performFetch(before: MessageArchvieID? = nil, limit: Int = 20, timeout: TimeInterval = 120.0) throws {
        try queue.sync {
            guard
                case .intitalized = self.state
                else { throw MessageArchiveRequestError.alreadyRunning }
            let request = self.makeRequest(before: before, limit: limit)
            self.iqHandler?.handleIQRequest(request, timeout: timeout) { [weak self] response, error in
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
            self.state = .fetching(messages: [:])
        }
    }
    
    private func handleResponse(_ stanza: IQStanza) {
        let namespaces = ["x": "urn:xmpp:mam:1"]
        guard
            let fin = stanza.nodes(forXPath: "./x:fin", usingNamespaces: namespaces).first as? PXElement,
            let rsm = fin.resultSet,
            let first = rsm.first,
            let last = rsm.last
            else {
                self.state = .failed(error: MessageArchiveRequestError.unexpectedResponse)
                return
        }
        
        guard
            case .fetching(let messages) = self.state
            else { return }
        
        let stable = Bool(fin.value(forAttribute: "stable") as? String ?? "") ?? true
        let complete = Bool(fin.value(forAttribute: "complete") as? String ?? "") ?? false
        
        let result = MessageArchiveRequestResult(
            first: first,
            last: last,
            stable: stable,
            complete: complete,
            messages: messages)
        
        self.state = .finished(result: result)
    }
    
    // MARK: - MessageHandler
    
    func handleMessage(_ message: MessageStanza, completion: ((Error?) -> Void)? = nil) {
        queue.async {
            guard
                let from = message.from,
                self.archive.account == from.bare()
                else {
                    completion?(nil)
                    return
                }
            
            do {
                if case .fetching(var messages) = self.state {
                    let now = Date()
                    let metadata = Metadata(created: now, transmitted: now, read: nil, error: nil, isCarbonCopy: false)
                    
                    guard
                        let result = try self.filter.apply(to: message, with: metadata, userInfo: [:]),
                        let archiveID = result.userInfo[MessageArchvieIDKey] as? String,
                        result.userInfo[MessageArchvieQueryIDKey] as? String == self.queryID
                        else {
                            completion?(nil)
                            return
                    }
                    
                    do {
                        let message = try self.archive.insert(result.message, metadata: result.metadata)
                        messages[archiveID] = message.messageID
                    } catch let error as MessageAlreadyExist {
                        messages[archiveID] = error.existingMessageID
                    }
                    
                    self.state = .fetching(messages: messages)
                }
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Helper
    
    private func makeRequest(before: MessageArchvieID?, limit: Int) -> IQStanza {
        let document = IQStanza.makeDocumentWithIQStanza(from: nil, to: archive.account.bare())
        let iq = document.root as! IQStanza
        iq.type = .set
        let query = iq.add(withName: "query", namespace: "urn:xmpp:mam:1", content: nil)!
        query.setValue(queryID, forAttribute: "queryid")
        query.addResultSet(withMax: 20, before: before ?? "")
        return iq
    }
}
