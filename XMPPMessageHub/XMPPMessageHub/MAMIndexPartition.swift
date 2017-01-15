//
//  MAMIndexPartition.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 07.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import Foundation

struct MAMIndexPartition: Equatable {
    let first: MessageArchiveID
    let last: MessageArchiveID
    let timestamp: Date
    let stable: Bool
    let complete: Bool
    let archvieIDs: Set<MessageArchiveID>
    let before: MessageArchiveID?
    
    static func ==(lhs: MAMIndexPartition, rhs: MAMIndexPartition) -> Bool {
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

extension MAMIndexPartition {
    func merge(_ other: MAMIndexPartition) -> (recent: MAMIndexPartition, other: MAMIndexPartition?) {
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
    
    static func +(lhs: MAMIndexPartition, rhs: MAMIndexPartition) -> MAMIndexPartition {
        return MAMIndexPartition(
            first: lhs.first,
            last: rhs.last,
            timestamp: lhs.timestamp,
            stable: lhs.stable && rhs.stable,
            complete: lhs.complete || rhs.complete,
            archvieIDs: lhs.archvieIDs.union(rhs.archvieIDs),
            before: rhs.before)
    }
}

extension MAMIndexPartition: Dictionariable {
    
    init?(dictionaryRepresentation: NSDictionary?) {
        guard
            let values = dictionaryRepresentation,
            let first = values["first"] as? MessageArchiveID,
            let last = values["last"] as? MessageArchiveID,
            let timestamp = values["timestamp"] as? Date,
            let stable = values["stable"] as? NSNumber,
            let complete = values["complete"] as? NSNumber,
            let archvieIDs = values["archvieIDs"] as? Set<MessageArchiveID>
            else {
                return nil
        }
        
        self.first = first
        self.last = last
        self.timestamp = timestamp
        self.stable = stable.boolValue
        self.complete = complete.boolValue
        self.archvieIDs = archvieIDs
        self.before = values["before"] as? MessageArchiveID
    }
    
    func dictionaryRepresentation() -> NSDictionary {
        var values: [String: Any] = [
            "first": first,
            "last": last,
            "timestamp": timestamp,
            "stable": NSNumber(value: stable),
            "complete": NSNumber(value: complete),
            "archvieIDs": archvieIDs
        ]
        if let before = self.before {
            values["before"] = before
        }
        return NSDictionary(dictionary: values)
    }
}
