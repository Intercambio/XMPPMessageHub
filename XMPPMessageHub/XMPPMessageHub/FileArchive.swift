//
//  FileArchive.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 20.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import CoreXMPP
import SQLite
import Dispatch

public class FileArchive: Archive {

    public let directory: URL
    public let account: JID
    
    private let queue: DispatchQueue
    
    required public init(directory: URL, account: JID) {
        queue = DispatchQueue(
            label: "Archive (\(account.stringValue))",
            attributes: [.concurrent])
        
        self.directory = directory
        self.account = account.bare()
    }
    
    private var store: ArchiveDocumentStore?
    private var db: SQLite.Connection?
    
    // MARK: - Open Archive
    
    public func open(completion: @escaping (Error?) -> Void) {
        queue.async(flags: [.barrier]) {
            do {
                try self.open()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    private func open() throws {
        let setup = Setup(directory: directory)
        let configuration = try setup.run()
        store = configuration.store
        db = configuration.db
    }
    
    // MARK: - Manage
    
    public func insert(_ document: PXDocument, metadata: Metadata) throws -> Message {
        return try queue.sync {
            
            guard
                let store = self.store,
                let db = self.db
                else { throw ArchiveError.notSetup }
            
            
            let uuid = UUID()
            let messageID = try self.makeMessageID(for: document, with: uuid)
            
            try store.write(document, with: uuid)
            try db.transaction {
                let _ = try db.run(
                    Schema.message.insert(
                        Schema.message_uuid <- messageID.uuid,
                        Schema.message_account <- messageID.account,
                        Schema.message_counterpart <- messageID.counterpart,
                        Schema.message_direction <- messageID.direction,
                        Schema.message_type <- messageID.type
                    )
                )
                let _ = try db.run(
                    Schema.metadata.insert(
                        Schema.metadata_uuid <- messageID.uuid,
                        Schema.metadata_created <- metadata.created,
                        Schema.metadata_transmitted <- metadata.transmitted,
                        Schema.metadata_read <- metadata.read,
                        Schema.metadata_thrashed <- metadata.thrashed,
                        Schema.metadata_error <- metadata.error as? NSError
                    )
                )
            }
            
            let message = Message(messageID: messageID, metadata: metadata)
            return message
        }
    }
    
    public func update(_ metadata: Metadata, for messageID: MessageID) throws -> Message {
        return try queue.sync {
            guard
                let db = self.db
                else { throw ArchiveError.notSetup }
            
            try db.transaction {
                let query = Schema.metadata.filter(Schema.metadata_uuid == messageID.uuid)
                let updated = try db.run(query.update(
                    Schema.metadata_uuid <- messageID.uuid,
                    Schema.metadata_created <- metadata.created,
                    Schema.metadata_transmitted <- metadata.transmitted,
                    Schema.metadata_read <- metadata.read,
                    Schema.metadata_thrashed <- metadata.thrashed,
                    Schema.metadata_error <- metadata.error as? NSError
                ))
                if updated != 1 {
                    throw ArchiveError.doesNotExist
                }
            }
            
            let message = Message(messageID: messageID, metadata: metadata)
            return message
        }
    }
    
    public func message(with messageID: MessageID) throws -> Message {
        return try queue.sync {
            let condition = Schema.metadata[Schema.metadata_uuid] == Schema.message[Schema.message_uuid]
            let query = Schema.message.join(Schema.metadata, on: condition)
            let filter = query.filter(Schema.metadata[Schema.metadata_uuid] == messageID.uuid)
            return try firstMessage(with: filter)
        }
    }
    
    public func document(for messageID: MessageID) throws -> PXDocument {
        return try queue.sync {
            guard let store = self.store else { throw ArchiveError.notSetup }
            return try store.read(documentWith: messageID.uuid)
        }
    }

    public func enumerateAll(_ block: @escaping (Message, Int, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        return try queue.sync {
            let condition = Schema.metadata[Schema.metadata_uuid] == Schema.message[Schema.message_uuid]
            let query = Schema.message.join(Schema.metadata, on: condition)
            
            try enumerateMessages(with: query, block: block)
        }
    }
    
    private func enumerateMessages(with query: QueryType, block: @escaping (Message, Int, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        guard
            let db = self.db
            else { throw ArchiveError.notSetup }
        
        try db.transaction {
            var index = 0
            var stop: ObjCBool = false
            for row in try db.prepare(query) {
                let message = try self.makeMessage(from: row)
                block(message, index, &stop)
                if stop.boolValue {
                    break
                } else {
                    index = index + 1
                }
            }
        }
    }
    
    private func firstMessage(with query: QueryType) throws -> Message {
        guard
            let db = self.db
            else { throw ArchiveError.notSetup }
        
        var message: Message? = nil
        
        try db.transaction {
            if let row = try db.pluck(query) {
                message = try self.makeMessage(from: row)
            }
        }
        
        if let message = message {
            return message
        } else {
            throw ArchiveError.doesNotExist
        }
    }
    
    private func makeMessage(from row: SQLite.Row) throws -> Message {
        let uuid = row.get(Schema.message[Schema.message_uuid])
        let account = row.get(Schema.message[Schema.message_account])
        let counterpart = row.get(Schema.message[Schema.message_counterpart])
        let direction = row.get(Schema.message[Schema.message_direction])
        let type = row.get(Schema.message[Schema.message_type])
        
        let messageID = MessageID(uuid: uuid, account: account, counterpart: counterpart, direction: direction, type: type)
        
        var metadata = Metadata()
        metadata.created = row.get(Schema.metadata[Schema.metadata_created])
        metadata.transmitted = row.get(Schema.metadata[Schema.metadata_transmitted])
        metadata.read = row.get(Schema.metadata[Schema.metadata_read])
        metadata.thrashed = row.get(Schema.metadata[Schema.metadata_thrashed])
        metadata.error = row.get(Schema.metadata[Schema.metadata_error])
        
        return Message(messageID: messageID, metadata: metadata)
    }
    
    // MARK: - Helper
    
    private func makeMessageID(for document: PXDocument, with uuid: UUID) throws -> MessageID {
        guard
            let message = document.root, message.qualifiedName == PXQName(name: "message", namespace: "jabber:client")
            else { throw ArchiveError.invalidDocument }
        
        guard
            let fromString = message.value(forAttribute: "from") as? String,
            let from = JID(fromString)
            else { throw ArchiveError.invalidDocument }
        
        guard
            let toString = message.value(forAttribute: "to") as? String,
            let to = JID(toString)
            else { throw ArchiveError.invalidDocument }
        
        guard
            account == from.bare() || account == to.bare()
            else { throw ArchiveError.accountMismatch }
        
        let direction: MessageDirection = account.isEqual(from.bare()) ? .outbound : .inbound
        let counterpart = direction == .outbound ? to.bare() : from.bare()
        let type = try self.type(of: message)
        
        return MessageID(uuid: uuid, account: account, counterpart: counterpart, direction: direction, type: type)
    }
    
    private func type(of message: PXElement) throws -> MessageType {
        if let typeString = message.value(forAttribute: "type") as? String,
            let type = MessageType(rawValue: typeString) {
            return type
        } else {
            return .normal
        }
    }
}

extension FileArchive: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Archive(account: \(account.stringValue), directiory: \(directory.absoluteString))"
    }
}
