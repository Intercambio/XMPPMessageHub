//
//  FileArchvieManagerTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import CoreXMPP
@testable import XMPPMessageHub

class FileArchvieManagerTests: TestCase {
    
    var archiveManager: ArchvieManager?
    
    override func setUp() {
        super.setUp()
        guard let directory = self.directory else { return }
        self.archiveManager = FileArchvieManager(directory: directory)
    }
    
    override func tearDown() {
        self.archiveManager = nil
        super.tearDown()
    }
    
    // MARK: Tests
    
    func testOpenArchive() {
        guard let archiveManager = self.archiveManager else { XCTFail(); return }
        
        var expectation = self.expectation(description: "Open")
        archiveManager.archive(for: JID("romeo@example.com")!, create: false) {
            archive, error in
            XCTAssertNil(archive)
            XCTAssertEqual(error as? ArchvieManagerError, ArchvieManagerError.doesNotExist)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        expectation = self.expectation(description: "Open")
        archiveManager.archive(for: JID("romeo@example.com")!, create: true) {
            archive, error in
            XCTAssertNotNil(archive)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        expectation = self.expectation(description: "Open")
        archiveManager.archive(for: JID("romeo@example.com")!, create: false) {
            archive, error in
            XCTAssertNotNil(archive)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        expectation = self.expectation(description: "Delete")
        archiveManager.deleteArchive(for: JID("romeo@example.com")!) {
            error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        expectation = self.expectation(description: "Open")
        archiveManager.archive(for: JID("romeo@example.com")!, create: false) {
            archive, error in
            XCTAssertNil(archive)
            XCTAssertEqual(error as? ArchvieManagerError, ArchvieManagerError.doesNotExist)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
