//
//  ArchiveProxy.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 04.12.16.
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
            object: archive
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func archiveDidChange(notification: Notification) {
        NotificationCenter.default.post(
            name: notification.name,
            object: self,
            userInfo: notification.userInfo
        )
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
    
    func loadRecentMessages(completion: ((Error?) -> Void)?) {
        mam.loadRecentMessages(for: account, completion: completion)
    }
    
    func loadMoreMessages(completion: ((Error?) -> Void)?) {
        mam.loadMoreMessages(for: account, completion: completion)
    }
}
