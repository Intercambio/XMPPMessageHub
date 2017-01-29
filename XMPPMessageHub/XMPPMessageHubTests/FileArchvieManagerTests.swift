//
//  FileArchvieManagerTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
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


import XCTest
import XMPPFoundation
@testable import XMPPMessageHub

class FileArchvieManagerTests: TestCase {
    
    var archiveManager: ArchiveManager?
    
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
            XCTAssertEqual(error as? ArchiveManagerError, ArchiveManagerError.doesNotExist)
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
            XCTAssertEqual(error as? ArchiveManagerError, ArchiveManagerError.doesNotExist)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
