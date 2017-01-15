//
//  MessageArchiveIndexTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import XCTest
@testable import XMPPMessageHub

class MessageArchiveIndexTests: TestCase {
    
    func testAddPartition() {
        
        let partitionA = MAMIndexPartition(
            first: "a",
            last: "f",
            timestamp: Date(timeIntervalSince1970: 100),
            stable: true,
            complete: false,
            archvieIDs: ["a", "b", "c", "d", "e", "f"],
            before: nil
        )
        
        let partitionB = MAMIndexPartition(
            first: "h",
            last: "l",
            timestamp: Date(timeIntervalSince1970: 120),
            stable: true,
            complete: false,
            archvieIDs: ["h", "i", "j", "k", "l"],
            before: nil
        )
        
        var index = MAMIndex(partitions: [partitionB, partitionA])
        
        let partition = MAMIndexPartition(
            first: "d",
            last: "j",
            timestamp: Date(timeIntervalSince1970: 110),
            stable: true,
            complete: false,
            archvieIDs: ["d", "e", "f", "g", "h", "i", "j"],
            before: nil
        )
        
        index = index.add(partition)
        XCTAssertEqual(index.partitions.count, 1)
    }
}
