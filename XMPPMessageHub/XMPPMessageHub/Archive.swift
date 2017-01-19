//
//  Archive.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 03.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
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
