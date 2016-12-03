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
    public var created: Date?
    public var transmitted: Date?
    public var read: Date?
    public var thrashed: Date?
    public var error: Error?
}

public struct MessageID {
    public let uuid: UUID
    public let account: JID
    public let counterpart: JID
    public let direction: MessageDirection
    public let type: MessageType
}

public struct Message {
    public let messageID: MessageID
    public let metadata: Metadata
}

extension MessageID: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "MessgaeID(uuid: \(uuid.uuidString), \(account.stringValue) \(direction.rawValue) \(counterpart.stringValue), type: \(type.rawValue))"
    }
}
