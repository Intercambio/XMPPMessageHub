//
//  FileArchiveSetup.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 21.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import SQLite
import  CoreXMPP

extension FileArchive {
    struct Schema {
        static let message = Table("message")
        static let message_uuid = Expression<UUID>("uuid")
        static let message_account = Expression<JID>("account")
        static let message_counterpart = Expression<JID>("counterpart")
        static let message_direction = Expression<MessageDirection>("direction")
        static let message_type = Expression<MessageType>("type")
        
        static let metadata = Table("metadata")
        static let metadata_uuid = Expression<UUID>("uuid")
        static let metadata_created = Expression<Date?>("created")
        static let metadata_transmitted = Expression<Date?>("transmitted")
        static let metadata_read = Expression<Date?>("read")
        static let metadata_thrashed = Expression<Date?>("thrashed")
        static let metadata_error = Expression<NSError?>("error")
    }
}

extension FileArchive {
    
    class Setup {
        
        static let version: Int = 1
        
        var version: Int {
            get {
                return readCurrentVersion()
            }
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
                attributes: [:])
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
            })
            try db.run(Schema.metadata.create { t in
                t.column(Schema.metadata_uuid, primaryKey: true)
                t.column(Schema.metadata_created)
                t.column(Schema.metadata_transmitted)
                t.column(Schema.metadata_read)
                t.column(Schema.metadata_thrashed)
                t.column(Schema.metadata_error)
                t.foreignKey(Schema.metadata_uuid, references: Schema.message, Schema.message_uuid)
            })
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


