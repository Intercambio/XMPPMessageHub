//
//  MessageArchiveRequestImpl.swift
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


import Foundation
import XMPPFoundation

class MessageArchiveRequestImpl: MessageArchiveRequest, MessageHandler {
    
    enum State {
        case intitalized
        case fetching(before: MessageArchiveID?, archvieIDs: Set<MessageArchiveID>, timestamp: Date?)
        case finished(response: MAMIndexPartition)
        case failed(error: Error)
    }
    
    weak var delegate: MessageArchiveRequestDelegate?
    
    let queryID: String
    
    private let dispatcher: Dispatcher
    private let archive: Archive
    
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
    
    required init(dispatcher: Dispatcher, archive: Archive) {
        self.dispatcher = dispatcher
        self.archive = archive
        self.queryID = UUID().uuidString.lowercased()
        queue = DispatchQueue(
            label: "MessageArchiveRequestImpl",
            attributes: []
        )
        dispatcher.add(self)
    }
    
    deinit {
        dispatcher.remove(self)
    }
    
    func performFetch(before: MessageArchiveID? = nil, limit: Int = 20, timeout: TimeInterval = 120.0) throws {
        try queue.sync {
            
            // WORKAROUND: The argument timeout needs to be "used" before the guard statement to
            // work around a swift compiler bug. If the argument is used directly in
            //
            //    self.dispatcher.handleIQRequest(request, timeout: timeout)
            //
            // below, the compiler will fail with "Segmentation fault: 11" if archiving.
            _ = timeout
            
            guard
                case .intitalized = self.state
            else { throw MessageArchiveRequestError.alreadyRunning }
            let request = self.makeRequest(before: before, limit: limit)
            self.dispatcher.handleIQRequest(request, timeout: timeout) { [weak self] response, error in
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
            self.state = .fetching(before: before, archvieIDs: Set<MessageArchiveID>(), timestamp: nil)
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
            case .fetching(let before, let archvieIDs, let timestamp) = self.state
        else { return }
        
        let stable = Bool(fin.value(forAttribute: "stable") as? String ?? "") ?? true
        let complete = Bool(fin.value(forAttribute: "complete") as? String ?? "") ?? false
        
        let response = MAMIndexPartition(
            first: first,
            last: last,
            timestamp: timestamp ?? Date(),
            stable: stable,
            complete: complete,
            archvieIDs: archvieIDs,
            before: before
        )
        
        self.state = .finished(response: response)
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
                if case .fetching(let before, var archvieIDs, var timestamp) = self.state {
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
                    
                    let host = JID(user: nil, host: self.archive.account.host, resource: nil)
                    
                    guard
                        (result.message.originID != nil) ||
                        (result.message.stanzaID(by: self.archive.account) != nil) ||
                        (result.message.stanzaID(by: host) != nil)
                    else {
                        NSLog("Dropping message for MAM request `\(self.queryID)`, because the message does not contain a origin-id or stanza-id which is needed for uniquing.")
                        completion?(nil)
                        return
                    }
                    
                    do {
                        let message = try self.archive.insert(result.message, metadata: result.metadata)
                        archvieIDs.insert(archiveID)
                        NSLog("Did archive message (\(archiveID)): \(message)")
                    } catch is MessageAlreadyExist {
                        archvieIDs.insert(archiveID)
                        NSLog("Message already archived (\(archiveID)).")
                    }
                    
                    if timestamp == nil {
                        timestamp = result.metadata.transmitted
                    }
                    
                    self.state = .fetching(before: before, archvieIDs: archvieIDs, timestamp: timestamp)
                }
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Helper
    
    private func makeRequest(before: MessageArchiveID?, limit: Int) -> IQStanza {
        let iq = IQStanza(type: .set, from: archive.account.bare(), to: archive.account.bare())
        let query = iq.add(withName: "query", namespace: "urn:xmpp:mam:1", content: nil)
        query.setValue(queryID, forAttribute: "queryid")
        query.addResultSet(withMax: limit, before: before ?? "")
        return iq
    }
}
