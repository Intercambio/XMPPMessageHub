//
//  MessageArchivePartition.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 07.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import Foundation

struct MessageArchivePartition: Equatable {
    let first: MessageArchvieID
    let last: MessageArchvieID
    let timestamp: Date
    let stable: Bool
    let complete: Bool
    let archvieIDs: Set<MessageArchvieID>
    let before: MessageArchvieID?
    
    static func ==(lhs: MessageArchivePartition, rhs: MessageArchivePartition) -> Bool {
        return
            lhs.first == rhs.first &&
            lhs.last == rhs.last &&
            lhs.timestamp == rhs.timestamp &&
            lhs.stable == rhs.stable &&
            lhs.complete == rhs.complete &&
            lhs.archvieIDs == rhs.archvieIDs &&
            lhs.before == rhs.before
    }
}

extension MessageArchivePartition {
    func merge(_ other: MessageArchivePartition) -> (recent: MessageArchivePartition, other: MessageArchivePartition?) {
        if self.archvieIDs.isDisjoint(with: other.archvieIDs) {
            if let before = self.before, other.first == before {
                return (self + other, nil)
            } else if let before = other.before, self.first == before {
                return (other + self, nil)
            } else if timestamp > other.timestamp {
                return (self, other)
            } else {
                return (other, self)
            }
        } else {
            if timestamp > other.timestamp {
                return (other + self, nil)
            } else {
                return (self + other, nil)
            }
        }
    }
    
    static func +(lhs: MessageArchivePartition, rhs: MessageArchivePartition) -> MessageArchivePartition {
        return MessageArchivePartition(
            first: lhs.first,
            last: rhs.last,
            timestamp: lhs.timestamp,
            stable: lhs.stable && rhs.stable,
            complete: lhs.complete || rhs.complete,
            archvieIDs: lhs.archvieIDs.union(rhs.archvieIDs),
            before: rhs.before)
    }
}
