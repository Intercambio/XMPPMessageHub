//
//  Message.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 22.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import CoreXMPP

public enum MessageType: String {
    case normal = "normal"
    case chat = "chat"
}

public enum MessageDirection: String {
    case inbound = "<-"
    case outbound = "->"
}

public struct Metadata {
    var created: Date?
    var transmitted: Date?
    var read: Date?
    var thrashed: Date?
    var error: Error?
}

public struct MessageID {
    let uuid: UUID
    let account: JID
    let counterpart: JID
    let direction: MessageDirection
    let type: MessageType
}

public struct Message {
    let messageID: MessageID
    let metadata: Metadata
}

extension MessageID: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "MessgaeID(uuid: \(uuid.uuidString), \(account.stringValue) \(direction.rawValue) \(counterpart.stringValue), type: \(type.rawValue))"
    }
}
