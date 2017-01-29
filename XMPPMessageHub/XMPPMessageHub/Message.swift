//
//  Message.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 22.11.16.
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

public protocol TransmissionError: Error, NSSecureCoding {
}

public enum MessageType: String {
    case chat
    case error
    case groupchat
    case headline
    case normal
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
    public var isCarbonCopy: Bool = false
    
    public init(created: Date? = nil, transmitted: Date? = nil, read: Date? = nil, error: TransmissionError? = nil, isCarbonCopy: Bool = false) {
        self.created = created
        self.transmitted = transmitted
        self.read = read
        self.error = error
        self.isCarbonCopy = isCarbonCopy
    }
}

public struct MessageID: Equatable, Hashable {
    public let uuid: UUID
    public let account: JID
    public let counterpart: JID
    public let direction: MessageDirection
    public let type: MessageType
    
    public let originID: String? // XEP-0359: unique-id
    public let stanzaID: String? // XEP-0359: stanza-id by the bare JID ot the account
    
    public static func ==(lhs: MessageID, rhs: MessageID) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    public var hashValue: Int {
        return uuid.hashValue
    }
}

public struct Message: Equatable, Hashable {
    public let messageID: MessageID
    public let metadata: Metadata
    
    public static func ==(lhs: Message, rhs: Message) -> Bool {
        return lhs.messageID == rhs.messageID
    }
    public var hashValue: Int {
        return messageID.hashValue
    }
}

extension MessageID: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "MessgaeID(uuid: \(uuid.uuidString), \(account.stringValue) \(direction.rawValue) \(counterpart.stringValue), type: \(type.rawValue))"
    }
}

extension NSError: TransmissionError {
}

extension MessageStanzaType {
    public var messageType: MessageType {
        switch self {
        case .chat: return .chat
        case .error: return .error
        case .groupchat: return .groupchat
        case .headline: return .headline
        default: return .normal
        }
    }
}
