//
//  MAMIndexManagerTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 15.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import XCTest
import XMPPFoundation
@testable import XMPPMessageHub

class MAMIndexManagerTests: TestCase {
    
    func testStoreIndex() {
        guard
            let directory = self.directory
        else {
            XCTFail()
            return
        }
        
        let manager = MAMIndexManager(directory: directory)
        do {
            
            let account = JID("romeo@example.com")!
            XCTAssertNil(try manager.nextArchvieID(for: account))
            
            let partition = MAMIndexPartition(
                first: "a",
                last: "f",
                timestamp: Date(timeIntervalSince1970: 100),
                stable: true,
                complete: false,
                archvieIDs: ["a", "b", "c", "d", "e", "f"],
                before: nil
            )
            
            try manager.add(partition, for: account)
            
            XCTAssertTrue(try manager.canLoadMoreMessages(for: account))
            XCTAssertEqual(try manager.nextArchvieID(for: account), "a")
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
}
