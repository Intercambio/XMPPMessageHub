//
//  Archive.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 03.12.16.
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
import PureXML
import XMPPFoundation

public enum ArchiveError: Error {
    case notSetup
    case invalidDocument
    case internalError
    case accountMismatch
    case doesNotExist
    case duplicateMessage
}

public struct MessageAlreadyExist: Error {
    public let existingMessageID: MessageID
}

public protocol Archive: class {
    var account: JID { get }
    
    func insert(_ stanza: MessageStanza, metadata: Metadata) throws -> Message
    func insert(_ document: PXDocument, metadata: Metadata) throws -> Message
    func update(_ metadata: Metadata, for messageID: MessageID) throws -> Message
    func update(transmitted: Date?, error: TransmissionError?, for messageID: MessageID) throws -> Message
    func delete(_ messageID: MessageID) throws
    
    func message(with messageID: MessageID) throws -> Message
    func document(for messageID: MessageID) throws -> PXDocument
    
    func all() throws -> [Message]
    func recent() throws -> [Message]
    func pending() throws -> [Message]
    func conversation(with counterpart: JID) throws -> [Message]
    
    func counterparts() throws -> [JID]
}

public protocol IncrementalArchive: Archive {
    var canLoadMore: Bool { get }
    func loadRecentMessages(completion: ((Error?) -> Void)?) -> Void
    func loadMoreMessages(completion: ((Error?) -> Void)?) -> Void
}

extension Archive {
    public func insert(_ stanza: MessageStanza, metadata: Metadata) throws -> Message {
        let document = PXDocument(element: stanza)
        return try insert(document, metadata: metadata)
    }
}

extension Notification.Name {
    public static let ArchiveDidChange = Notification.Name("XMPPMessageHubArchiveDidChange")
}

public let InsertedMessagesKey: String = "XMPPMessageHubInsertedMessagesKey"
public let UpdatedMessagesKey: String = "XMPPMessageHubUpdatedMessagesKey"
public let DeletedMessagesKey: String = "XMPPMessageHubDeletedMessagesKey"
