//
//  ArchiveProxy.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation
import PureXML

protocol ArchiveProxyDelegate: class {
    func archiveProxy(_ proxy: ArchiveProxy, didInsert message: Message, with document: PXDocument) -> Void
}

class ArchiveProxy: IncrementalArchive {
    
    weak var delegate: ArchiveProxyDelegate?

    let mam: MessageArchiveManagement
    let archive: Archive
    
    init(archive: Archive, mam: MessageArchiveManagement) {
        self.archive = archive
        self.mam = mam
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(archiveDidChange(notification:)),
            name: nil,
            object: archive)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func archiveDidChange(notification: Notification) {
        NotificationCenter.default.post(name: notification.name,
                                        object: self,
                                        userInfo: notification.userInfo)
    }
    
    // MARK: - Archive
    
    var account: JID { return archive.account }
    
    func insert(_ document: PXDocument, metadata: Metadata) throws -> Message {
        if let message = document.root as? MessageStanza {
            message.originID = UUID().uuidString.lowercased()
        }
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
    
    // MARK: - IncrementalArchive
    
    var canLoadMore: Bool {
        return mam.canLoadMoreMessages(for: account)
    }
    
    func loadRecentMessages(completion: ((Error?) -> Void)?) -> Void {
        mam.loadRecentMessages(for: account, completion: completion)
    }
    
    func loadMoreMessages(completion: ((Error?) -> Void)?) -> Void {
        mam.loadMoreMessages(for: account, completion: completion)
    }
}
