//
//  Archive.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 20.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import CoreXMPP
import Dispatch

enum ArchiveError:  Error {
    case invalidDocument
    case internalError
}

public class Archive {

    public let directory: URL
    
    private let queue: DispatchQueue = DispatchQueue(label: "org.intercambio.XMPPMessageHub.Archive")
    required public init(directory: URL) {
        self.directory = directory
    }
    
    // MARK: - Open Archive
    
    public func open(completion: @escaping (Error?) ->Void) {
        queue.async {
            do {
                try self.open()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    private func open() throws {
        if let setup = Setup.makeSetup(from: readCurrentVersion(), directory: directory) {
            version = try setup.run()
            try writeCurrentVersion(version)
        }
    }
    
    // MARK: - Manage
    
    public func insert(_ document: PXDocument, metadata: Metadata) throws -> Message {
        return try queue.sync {
            let uuid = NSUUID()
            let messageID = try self.makeMessageID(for: document, with: uuid)
            try write(document, with: messageID)
            let message = Message(messageID: messageID, metadata: metadata)
            return message
        }
    }
    
    public func document(for messageID: MessageID) throws -> PXDocument {
        return try read(with: messageID)
    }
    
    private func makeMessageID(for document: PXDocument, with uuid: NSUUID) throws -> MessageID {
        
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
        
        let type = try self.type(of: document)
        
        return MessageID(uuid: uuid, from: from, to: to, type: type)
    }
    
    private func type(of document: PXDocument) throws -> MessageType {
        guard
            let message = document.root, message.qualifiedName == PXQName(name: "message", namespace: "jabber:client")
            else { throw ArchiveError.invalidDocument }
        
        if let typeString = message.value(forAttribute: "type") as? String,
            let type = MessageType(rawValue: typeString) {
            return type
        } else {
            return .normal
        }
    }
    
    // MARK: - Documents
    
    private func write(_ document: PXDocument, with messageID: MessageID) throws {
        if let data = document.data() {
            try data.write(to: path(for: messageID))
        } else {
            throw ArchiveError.internalError
        }
    }
    
    private func read(with messageID: MessageID) throws -> PXDocument {
        let data = try Data(contentsOf: path(for: messageID))
        return PXDocument(data: data)
    }
    
    private func path(for messageID: MessageID) -> URL {
        let name = "\(messageID.uuid.uuidString.lowercased()).xml"
        return messagesDirectory.appendingPathComponent(name)
    }
    
    private var messagesDirectory: URL {
        return URL(fileURLWithPath: "messages", isDirectory: true, relativeTo: directory)
    }
    
    // MARK: - Archive Version
    
    public private(set) var version: Int = 0
    
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
