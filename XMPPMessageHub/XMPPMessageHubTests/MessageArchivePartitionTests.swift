//
//  MessageArchivePartitionTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 07.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import XCTest
@testable import XMPPMessageHub

class MessageArchivePartitionTests: TestCase {
    
    func testMergeNonIntersecting() {
        
        let partitionA = MessageArchivePartition(
            first: "a",
            last: "f",
            timestamp: Date(timeIntervalSince1970: 100),
            stable: true,
            complete: false,
            archvieIDs: ["a", "b", "c", "d", "e", "f"],
            before: nil)
        
        let partitionB = MessageArchivePartition(
            first: "h",
            last: "l",
            timestamp: Date(timeIntervalSince1970: 120),
            stable: true,
            complete: false,
            archvieIDs: ["h", "i", "j", "k", "l"],
            before: nil)
        
        var (recent, other) = partitionA.merge(partitionB)
        XCTAssertEqual(recent, partitionB)
        XCTAssertEqual(other, partitionA)
        
        (recent, other) = partitionB.merge(partitionA)
        XCTAssertEqual(recent, partitionB)
        XCTAssertEqual(other, partitionA)
    }
    
    func testMergeConsecutive() {
        
        let partitionA = MessageArchivePartition(
            first: "a",
            last: "f",
            timestamp: Date(timeIntervalSince1970: 100),
            stable: true,
            complete: false,
            archvieIDs: ["a", "b", "c", "d", "e", "f"],
            before: "g")
        
        let partitionB = MessageArchivePartition(
            first: "g",
            last: "l",
            timestamp: Date(timeIntervalSince1970: 120),
            stable: true,
            complete: false,
            archvieIDs: ["g", "h", "i", "j", "k", "l"],
            before: "x")
        
        
        let (recentX, otherX) = partitionA.merge(partitionB)
        XCTAssertNil(otherX)
        XCTAssertEqual(recentX.first, "a")
        XCTAssertEqual(recentX.last, "l")
        XCTAssertEqual(recentX.before, "x")
        XCTAssertEqual(recentX.timestamp, Date(timeIntervalSince1970: 100))
        
        let (recentY, otherY) = partitionB.merge(partitionA)
        XCTAssertNil(otherY)
        XCTAssertEqual(recentY, recentX)
    }
    
    func testMergeIntersecting() {
        
        let partitionA = MessageArchivePartition(
            first: "a",
            last: "f",
            timestamp: Date(timeIntervalSince1970: 100),
            stable: true,
            complete: false,
            archvieIDs: ["a", "b", "c", "d", "e", "f"],
            before: "g")
        
        let partitionB = MessageArchivePartition(
            first: "d",
            last: "i",
            timestamp: Date(timeIntervalSince1970: 120),
            stable: true,
            complete: false,
            archvieIDs: ["d", "e", "f", "g", "h", "i"],
            before: "x")
        
        let (recentX, otherX) = partitionA.merge(partitionB)
        XCTAssertNil(otherX)
        XCTAssertEqual(recentX.first, "a")
        XCTAssertEqual(recentX.last, "i")
        XCTAssertEqual(recentX.before, "x")
        XCTAssertEqual(recentX.timestamp, Date(timeIntervalSince1970: 100))
        
        let (recentY, otherY) = partitionB.merge(partitionA)
        XCTAssertNil(otherY)
        XCTAssertEqual(recentY, recentX)
    }
    
    func testArchiving() {
        
        let partition = MessageArchivePartition(
            first: "a",
            last: "f",
            timestamp: Date(timeIntervalSince1970: 100),
            stable: true,
            complete: false,
            archvieIDs: ["a", "b", "c", "d", "e", "f"],
            before: nil)
        
        let data = NSKeyedArchiver.archivedData(withStructure: partition) 
        
        XCTAssertEqual(NSKeyedUnarchiver.unarchiveStructure(with: data), partition)
    }
}
