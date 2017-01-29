//
//  FileArchiveSetup.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 21.11.16.
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
import SQLite
import XMPPFoundation

extension FileArchive {
    struct Schema {
        static let message = Table("message")
        static let message_uuid = Expression<UUID>("uuid")
        static let message_account = Expression<JID>("account")
        static let message_counterpart = Expression<JID>("counterpart")
        static let message_direction = Expression<MessageDirection>("direction")
        static let message_type = Expression<MessageType>("type")
        static let message_origin_id = Expression<String?>("origin_id")
        static let message_stanza_id = Expression<String?>("stanza_id")
        
        static let metadata = Table("metadata")
        static let metadata_uuid = Expression<UUID>("uuid")
        static let metadata_created = Expression<Date?>("created")
        static let metadata_transmitted = Expression<Date?>("transmitted")
        static let metadata_read = Expression<Date?>("read")
        static let metadata_error = Expression<NSError?>("error")
        static let metadata_is_carbon_copy = Expression<Bool>("is_carbon_copy")
    }
}

extension FileArchive {
    
    class Setup {
        
        static let version: Int = 1
        
        var version: Int {
            return readCurrentVersion()
        }
        
        let directory: URL
        required init(directory: URL) {
            self.directory = directory
        }
        
        var messagesLocation: URL {
            return directory.appendingPathComponent("messages", isDirectory: true)
        }
        
        var databaseLocation: URL {
            return directory.appendingPathComponent("db.sqlite", isDirectory: false)
        }
        
        func run() throws -> (store: ArchiveDocumentStore, db: SQLite.Connection) {
            let db = try createDatabase()
            if readCurrentVersion() == 0 {
                try createMessageDirectory()
                try setup(db)
                try writeCurrentVersion(Setup.version)
            }
            let store = FileArchiveFileDocumentStore(directory: messagesLocation)
            return (store, db)
        }
        
        private func createMessageDirectory() throws {
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: messagesLocation,
                withIntermediateDirectories: false,
                attributes: [:]
            )
        }
        
        private func createDatabase() throws -> SQLite.Connection {
            let db = try Connection(databaseLocation.path)
            
            db.busyTimeout = 5
            db.busyHandler({ tries in
                if tries >= 3 {
                    return false
                }
                return true
            })
            
            return db
        }
        
        private func setup(_ db: SQLite.Connection) throws {
            try db.run(Schema.message.create { t in
                t.column(Schema.message_uuid, primaryKey: true)
                t.column(Schema.message_account)
                t.column(Schema.message_direction)
                t.column(Schema.message_counterpart)
                t.column(Schema.message_type)
                t.column(Schema.message_origin_id)
                t.column(Schema.message_stanza_id)
            })
            try db.run(Schema.message.createIndex(Schema.message_account))
            try db.run(Schema.message.createIndex(Schema.message_counterpart))
            try db.run(Schema.message.createIndex(Schema.message_origin_id))
            try db.run(Schema.message.createIndex(Schema.message_stanza_id))
            try db.run(Schema.metadata.create { t in
                t.column(Schema.metadata_uuid, primaryKey: true)
                t.column(Schema.metadata_created)
                t.column(Schema.metadata_transmitted)
                t.column(Schema.metadata_read)
                t.column(Schema.metadata_error)
                t.column(Schema.metadata_is_carbon_copy)
                t.foreignKey(Schema.metadata_uuid, references: Schema.message, Schema.message_uuid)
            })
            try db.run(Schema.metadata.createIndex(Schema.metadata_created))
            try db.run(Schema.metadata.createIndex(Schema.metadata_transmitted))
        }
        
        private func readCurrentVersion() -> Int {
            let url = directory.appendingPathComponent("version.txt")
            do {
                let versionText = try String(contentsOf: url)
                guard let version = Int(versionText) else { return 0 }
                return version
            } catch {
                return 0
            }
        }
        
        private func writeCurrentVersion(_ version: Int) throws {
            let url = directory.appendingPathComponent("version.txt")
            let versionData = String(version).data(using: .utf8)
            try versionData?.write(to: url)
        }
    }
}
