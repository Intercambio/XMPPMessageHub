//
//  FileArchive.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 20.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import XMPPFoundation
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
    
    public func close() {
        queue.sync(flags: [.barrier]) {
            self.store = nil
            self.db = nil
        }
    }
    
    private func open() throws {
        let setup = Setup(directory: directory)
        let configuration = try setup.run()
        store = configuration.store
        db = configuration.db
    }
    
    // MARK: Insert, Update and Delete Messages
    
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
                
                if let existingMessageID = try self.existingMessageID(matching: messageID) {
                    throw MessageAlreadyExist(existingMessageID: existingMessageID)
                }
                
                let _ = try db.run(
                    Schema.message.insert(
                        Schema.message_uuid <- messageID.uuid,
                        Schema.message_account <- messageID.account,
                        Schema.message_counterpart <- messageID.counterpart,
                        Schema.message_direction <- messageID.direction,
                        Schema.message_type <- messageID.type,
                        Schema.message_origin_id <- messageID.originID,
                        Schema.message_stanza_id <- messageID.stanzaID
                    )
                )
                let _ = try db.run(
                    Schema.metadata.insert(
                        Schema.metadata_uuid <- messageID.uuid,
                        Schema.metadata_created <- metadata.created,
                        Schema.metadata_transmitted <- metadata.transmitted,
                        Schema.metadata_read <- metadata.read,
                        Schema.metadata_error <- metadata.error as? NSError,
                        Schema.metadata_is_carbon_copy <- metadata.isCarbonCopy
                    )
                )
            }
            
            let message = Message(messageID: messageID, metadata: metadata)
            self.postChangeNotificationFor(inserted: [message])
            return message
        }
    }
    
    private func existingMessageID(matching messageID: MessageID) throws -> MessageID? {
        guard
            let db = self.db
            else { throw ArchiveError.notSetup }
        
        let account = messageID.account.bare()
        let counterpart = messageID.counterpart.bare()
        let direction = messageID.direction
        
        if let originID = messageID.originID {
            
            let query = Schema.message.filter(
                Schema.message_origin_id == originID
                    && Schema.message_account == account
                    && Schema.message_counterpart == counterpart
                    && Schema.message_direction == direction)
            
            if let row = try db.pluck(query) {
                return try makeMessageID(from: row)
            }
        }
        
        if let stanzaID = messageID.stanzaID {
            let query = Schema.message.filter(
                Schema.message_stanza_id == stanzaID
                    && Schema.message_account == account
                    && Schema.message_counterpart == counterpart
                    && Schema.message_direction == direction)
            
            if let row = try db.pluck(query) {
                return try makeMessageID(from: row)
            }
        }
        
        return nil
    }

    public func update(_ metadata: Metadata, for messageID: MessageID) throws -> Message {
        return try queue.sync {
            guard
                let db = self.db
                else { throw ArchiveError.notSetup }
            
            var message: Message? = nil
            
            try db.transaction {
                let metadataQuery = Schema.metadata.filter(Schema.metadata_uuid == messageID.uuid)
                let updated = try db.run(metadataQuery.update(
                    Schema.metadata_created <- metadata.created,
                    Schema.metadata_transmitted <- metadata.transmitted,
                    Schema.metadata_read <- metadata.read,
                    Schema.metadata_error <- metadata.error as? NSError,
                    Schema.metadata_is_carbon_copy <- metadata.isCarbonCopy
                ))
                if updated != 1 {
                    throw ArchiveError.doesNotExist
                }
                let filter = Schema.metadata[Schema.metadata_uuid] == messageID.uuid
                let messageQuery = self.makeMessageQuery(with: [Expression<Bool?>(filter)])
                if let row = try db.pluck(messageQuery) {
                    message = try self.makeMessage(from: row)
                }
            }
            
            guard
                let result = message
                else { throw ArchiveError.doesNotExist }
            
            self.postChangeNotificationFor(updated: [result])
            return result
        }
    }
    
    public func update(transmitted: Date?, error: TransmissionError?, for messageID: MessageID) throws -> Message {
        return try queue.sync {
            guard
                let db = self.db
                else { throw ArchiveError.notSetup }
            
            var message: Message? = nil
            
            try db.transaction {
                let metadataQuery = Schema.metadata.filter(Schema.metadata_uuid == messageID.uuid)
                let updated = try db.run(metadataQuery.update(
                    Schema.metadata_transmitted <- transmitted,
                    Schema.metadata_error <- error as? NSError
                ))
                if updated != 1 {
                    throw ArchiveError.doesNotExist
                }
                let filter = Schema.metadata[Schema.metadata_uuid] == messageID.uuid
                let messageQuery = self.makeMessageQuery(with: [Expression<Bool?>(filter)])
                if let row = try db.pluck(messageQuery) {
                    message = try self.makeMessage(from: row)
                }
            }
            
            guard
                let result = message
                else { throw ArchiveError.doesNotExist }
            
            self.postChangeNotificationFor(updated: [result])
            return result
        }
    }
    
    public func delete(_ messageID: MessageID) throws {
        try queue.sync {
            guard
                let store = self.store,
                let db = self.db
                else { throw ArchiveError.notSetup }
            
            var message: Message? = nil
            
            try db.transaction {
                
                let filter = Schema.metadata[Schema.metadata_uuid] == messageID.uuid
                let messageQuery = self.makeMessageQuery(with: [Expression<Bool?>(filter)])
                guard
                    let row = try db.pluck(messageQuery)
                    else { throw ArchiveError.doesNotExist  }
                
                message = try self.makeMessage(from: row)

                let _ = try db.run(Schema.message.filter(Schema.message_uuid == messageID.uuid).delete())
                let _ = try db.run(Schema.metadata.filter(Schema.metadata_uuid == messageID.uuid).delete())
                try store.delete(documentWith: messageID.uuid)
            }
            
            guard
                let result = message
                else { throw ArchiveError.doesNotExist }
            
            self.postChangeNotificationFor(deleted: [result])
        }
    }
    
    private func postChangeNotificationFor(inserted: [Message]? = nil, updated: [Message]? = nil, deleted: [Message]? = nil) {
        var userInfo: [AnyHashable : Any] = [:]
        userInfo[InsertedMessagesKey] = inserted
        userInfo[UpdatedMessagesKey] = updated
        userInfo[DeletedMessagesKey] = deleted
        let notification = Notification(name: Notification.Name.ArchiveDidChange,
                                        object: self,
                                        userInfo: userInfo)
        let notificationCenter = NotificationCenter.default
        DispatchQueue.global().async {
            notificationCenter.post(notification)
        }
    }
    
    // MARK: Get Message and Document
    
    public func message(with messageID: MessageID) throws -> Message {
        return try queue.sync {
            let filter = Schema.metadata[Schema.metadata_uuid] == messageID.uuid
            return try firstMessage(filter: [Expression<Bool?>(filter)])
        }
    }
    
    public func document(for messageID: MessageID) throws -> PXDocument {
        return try queue.sync {
            guard
                let store = self.store
                else { throw ArchiveError.notSetup }
            
            return try store.read(documentWith: messageID.uuid)
        }
    }
    
    // MARK: Query Messages
    
    public func all() throws -> [Message] {
        return try queue.sync {
            return try messages()
        }
    }
    
    public func recent() throws -> [Message] {
        return try queue.sync {
            guard
                let db = self.db
                else { throw ArchiveError.notSetup }
            
            var messages: [Message] = []
            try db.transaction {
                let query = Schema.message.select(distinct: Schema.message_counterpart)
                for row in try db.prepare(query) {
                    let jid = row.get(Schema.message_counterpart)
                    
                    let filter = Schema.message[Schema.message_counterpart] == jid
                    let query = self.makeMessageQuery(with: [Expression<Bool?>(filter)])
                    
                    if let row = try db.pluck(query) {
                        let message = try self.makeMessage(from: row)
                        messages.append(message)
                    }
                }
            }
            return messages
        }
    }
    
    public func pending() throws -> [Message] {
        return try queue.sync {
            let filters = [Schema.metadata[Schema.metadata_transmitted] == nil,
                           Schema.metadata[Schema.metadata_error] == nil]
            return try messages(filter: filters)
        }
    }
    
    public func conversation(with counterpart: JID) throws -> [Message] {
        return try queue.sync {
            let filter = Schema.message[Schema.message_counterpart] == counterpart.bare()
            return try messages(filter: [Expression<Bool?>(filter)])
        }
    }
    
    // MARK: Counterparts
    
    public func counterparts() throws -> [JID] {
        return try queue.sync {
            guard
                let db = self.db
                else { throw ArchiveError.notSetup }
            
            var jids: [JID] = []
            try db.transaction {
                let query = Schema.message.select(distinct: Schema.message_counterpart)
                for row in try db.prepare(query) {
                    let jid = row.get(Schema.message_counterpart)
                    jids.append(jid)
                }
            }
            return jids
        }
    }
    
    // MARK: -
    
    private func enumerateMessages(filter: [SQLite.Expression<Bool?>] = [],
                                   block: @escaping (Message, Int, UnsafeMutablePointer<ObjCBool>) -> Void) throws -> Void {
        guard
            let db = self.db
            else { throw ArchiveError.notSetup }
        
        let query = makeMessageQuery(with: filter)
        
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
    
    private func messages(filter: [SQLite.Expression<Bool?>] = []) throws -> [Message] {
        guard
            let db = self.db
            else { throw ArchiveError.notSetup }
        
        let query = makeMessageQuery(with: filter)
        
        var result: [Message] = []
        try db.transaction {
            for row in try db.prepare(query) {
                let message = try self.makeMessage(from: row)
                result.append(message)
            }
        }
        return result
    }

    private func firstMessage(filter: [SQLite.Expression<Bool?>] = []) throws -> Message {
        guard
            let db = self.db
            else { throw ArchiveError.notSetup }
        
        let query = makeMessageQuery(with: filter)
        
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
    
    private func makeMessageQuery(with filter: [SQLite.Expression<Bool?>] = []) -> QueryType {
        let condition = Schema.metadata[Schema.metadata_uuid] == Schema.message[Schema.message_uuid]
        var query = Schema.message.join(Schema.metadata, on: condition)
        
        for expresion in filter {
            query = query.filter(expresion)
        }
        
        let transmitted = Expression<Date>("transmitted")
        let created = Expression<Date>("created")
        
        query = query.order([
            transmitted.desc,
            created.desc,
            Schema.message[rowid].desc
            ])

        query = query.select(
            Schema.message[Schema.message_uuid],
            Schema.message[Schema.message_account],
            Schema.message[Schema.message_counterpart],
            Schema.message[Schema.message_direction],
            Schema.message[Schema.message_type],
            Schema.message[Schema.message_origin_id],
            Schema.message[Schema.message_stanza_id],
            Schema.metadata[Schema.metadata_created],
            Schema.metadata[Schema.metadata_transmitted],
            Schema.metadata[Schema.metadata_read],
            Schema.metadata[Schema.metadata_error],
            Schema.metadata[Schema.metadata_is_carbon_copy],
            (Schema.metadata[Schema.metadata_transmitted] ?? Date.distantFuture).alias(name: "transmitted"),
            (Schema.metadata[Schema.metadata_created] ?? Date.distantFuture).alias(name: "created")
        )
        return query
    }
    
    private func makeMessage(from row: SQLite.Row) throws -> Message {
        let uuid = row.get(Schema.message[Schema.message_uuid])
        let account = row.get(Schema.message[Schema.message_account])
        let counterpart = row.get(Schema.message[Schema.message_counterpart])
        let direction = row.get(Schema.message[Schema.message_direction])
        let type = row.get(Schema.message[Schema.message_type])
        let originID = row.get(Schema.message[Schema.message_origin_id])
        let stanzaID = row.get(Schema.message[Schema.message_stanza_id])
        
        let messageID = MessageID(
            uuid: uuid,
            account: account,
            counterpart: counterpart,
            direction: direction,
            type: type,
            originID: originID,
            stanzaID: stanzaID)
        
        var metadata = Metadata()
        metadata.created = row.get(Schema.metadata[Schema.metadata_created])
        metadata.transmitted = row.get(Schema.metadata[Schema.metadata_transmitted])
        metadata.read = row.get(Schema.metadata[Schema.metadata_read])
        metadata.error = row.get(Schema.metadata[Schema.metadata_error])
        metadata.isCarbonCopy = row.get(Schema.metadata[Schema.metadata_is_carbon_copy])
        
        return Message(
            messageID: messageID,
            metadata: metadata)
    }
    
    private func makeMessageID(from row: SQLite.Row) throws -> MessageID {
        let uuid = row.get(Schema.message_uuid)
        let account = row.get(Schema.message_account)
        let counterpart = row.get(Schema.message_counterpart)
        let direction = row.get(Schema.message_direction)
        let type = row.get(Schema.message_type)
        let originID = row.get(Schema.message_origin_id)
        let stanzaID = row.get(Schema.message_stanza_id)
        
        let messageID = MessageID(
            uuid: uuid,
            account: account,
            counterpart: counterpart,
            direction: direction,
            type: type,
            originID: originID,
            stanzaID: stanzaID)
        
        return messageID
    }
    
    private func makeMessageID(for document: PXDocument, with uuid: UUID) throws -> MessageID {
        guard
            let message = document.root as? MessageStanza,
            let from = message.from,
            let to = message.to
            else { throw ArchiveError.invalidDocument }
        
        guard
            account == from.bare() || account == to.bare()
            else { throw ArchiveError.accountMismatch }
        
        let direction: MessageDirection = account.isEqual(from.bare()) ? .outbound : .inbound
        let counterpart = direction == .outbound ? to.bare() : from.bare()
        let type = message.type.messageType
        let originID = message.originID
        let stanzaID = message.stanzaID(by: account.bare())
        
        return MessageID(
            uuid: uuid,
            account: account,
            counterpart: counterpart,
            direction: direction,
            type: type,
            originID: originID,
            stanzaID: stanzaID)
    }
}

extension FileArchive: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Archive(account: \(account.stringValue), directiory: \(directory.absoluteString))"
    }
}
