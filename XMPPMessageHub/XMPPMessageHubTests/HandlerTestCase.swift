//
//  HandlerTestCase.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 30.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import XMPPFoundation
@testable import XMPPMessageHub

class HandlerTestCase: TestCase {
    
    var archiveManager: ArchiveManager?
    
    override func setUp() {
        super.setUp()
        
        guard
            let directory = self.directory
            else { return }
        
        archiveManager = FileArchvieManager(directory: directory)
    }
    
    override func tearDown() {
        archiveManager = nil
        super.tearDown()
    }
    
    func archive(for account: JID) -> Archive? {
        guard
            let archiveManager = self.archiveManager
            else { return nil }
        
        var result: Archive? = nil
        let exp = expectation(description: "Get Archive for '\(account.stringValue)'")
        archiveManager.archive(for: account, create: true) {
            archive, error in
            result = archive
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        return result
    }
}
