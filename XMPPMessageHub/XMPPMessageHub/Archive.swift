//
//  Archive.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 03.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import CoreXMPP

public enum ArchiveError:  Error {
    case notSetup
    case invalidDocument
    case internalError
    case accountMismatch
    case doesNotExist
}

public protocol Archive {
    var account: JID { get }
    func open(completion: @escaping (Error?) -> Void) -> Void
    
    func insert(_ document: PXDocument, metadata: Metadata) throws -> Message
    func update(_ metadata: Metadata, for messageID: MessageID) throws -> Message
    
    func document(for messageID: MessageID) throws -> PXDocument
    
    func message(with messageID: MessageID) throws -> Message
    func all() throws -> [Message]
    func conversation(with counterpart: JID) throws -> [Message]
    func recent() throws -> [Message]
    func pending() throws -> [Message]
    
    func enumerateAll(_ block: @escaping (Message, Int, UnsafeMutablePointer<ObjCBool>) -> Void) throws -> Void
    func enumerateConversation(with counterpart: JID, _ block: @escaping (Message, Int, UnsafeMutablePointer<ObjCBool>) -> Void) throws -> Void
    
    func counterparts() throws -> [JID]
}
