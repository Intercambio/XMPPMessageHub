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
    case notSetup
    case invalidDocument
    case internalError
}

public class Archive {

    public let directory: URL
    
    private let queue: DispatchQueue = DispatchQueue(label: "org.intercambio.XMPPMessageHub.Archive")
    required public init(directory: URL) {
        self.directory = directory
    }
    
    private var store: ArchiveDocumentStore?
    
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
        let setup = Setup(directory: directory)
        store = try setup.run()
    }
    
    // MARK: - Manage
    
    public func insert(_ document: PXDocument, metadata: Metadata) throws -> Message {
        guard let store = self.store else { throw ArchiveError.notSetup }
        return try queue.sync {
            let uuid = UUID()
            let messageID = try self.makeMessageID(for: document, with: uuid)
            try store.write(document, with: uuid)
            let message = Message(messageID: messageID, metadata: metadata)
            return message
        }
    }
    
    public func document(for messageID: MessageID) throws -> PXDocument {
        guard let store = self.store else { throw ArchiveError.notSetup }
        return try store.read(documentWith: messageID.uuid)
    }
    
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
}
