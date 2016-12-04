//
//  ArchiveProxy.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import CoreXMPP
import PureXML

protocol ArchiveProxyDelegate: class {
    func archiveProxy(_ proxy: ArchiveProxy, didInsert message: Message, with document: PXDocument) -> Void
}

class ArchiveProxy: Archive {
    
    weak var delegate: ArchiveProxyDelegate?
    
    let archive: Archive
    init(archive: Archive, delegate: ArchiveProxyDelegate? = nil) {
        self.delegate = delegate
        self.archive = archive
    }
    
    // MARK: - Archive
    
    var account: JID { return archive.account }
    
    func insert(_ document: PXDocument, metadata: Metadata) throws -> Message {
        let message = try archive.insert(document, metadata: metadata)
        delegate?.archiveProxy(self, didInsert: message, with: document)
        return message
    }
    
    func update(_ metadata: Metadata, for messageID: MessageID) throws -> Message { return try archive.update(metadata, for: messageID) }
    
    func update(transmitted: Date?, error: TransmissionError?, for messageID: MessageID) throws -> Message {
        return try archive.update(transmitted: transmitted, error: error, for: messageID)
    }
    
    func delete(_ messageID: MessageID) throws { try archive.delete(messageID) }
    func message(with messageID: MessageID) throws -> Message { return try archive.message(with: messageID) }
    func document(for messageID: MessageID) throws -> PXDocument { return try archive.document(for: messageID) }
    func all() throws -> [Message] { return try archive.all() }
    func recent() throws -> [Message] { return try archive.recent() }
    func pending() throws -> [Message] { return try archive.pending() }
    func conversation(with counterpart: JID) throws -> [Message] { return try archive.conversation(with: counterpart) }
    func counterparts() throws -> [JID] { return try counterparts() }
}

