//
//  Message.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 22.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import CoreXMPP

public protocol TransmissionError: Error, NSSecureCoding {
}

public enum MessageType: String {
    case chat = "chat"
    case error = "error"
    case groupchat = "groupchat"
    case headline = "headline"
    case normal = "normal"
}

public enum MessageDirection: String {
    case inbound = "<-"
    case outbound = "->"
}

public struct Metadata {
    public var created: Date?
    public var transmitted: Date?
    public var read: Date?
    public var error: TransmissionError?
    public var forwarded: Bool = false
}

public struct MessageID: Equatable, Hashable {
    public let uuid: UUID
    public let account: JID
    public let counterpart: JID
    public let direction: MessageDirection
    public let type: MessageType
    
    public static func ==(lhs: MessageID, rhs: MessageID) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    public var hashValue: Int {
        return uuid.hashValue
    }
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

extension NSError: TransmissionError {
}
