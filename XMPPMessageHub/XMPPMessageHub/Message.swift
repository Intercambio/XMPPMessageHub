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

public struct Metadata {
    var created: Date?
    var transmitted: Date?
    var read: Date?
    var thrashed: Date?
    var error: Error?
}

public struct MessageID {
    let uuid: NSUUID
    let from: JID
    let to: JID
    let type: MessageType
}

public struct Message {
    let messageID: MessageID
    let metadata: Metadata
}


extension MessageID: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "MessgaeID(uuid: \(uuid.uuidString), from: \(from.stringValue), to: \(to.stringValue), type: \(type.rawValue))"
    }
}
