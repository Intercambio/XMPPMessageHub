//
//  ArchiveTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 20.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
@testable import XMPPMessageHub

class ArchiveTests: TestCase {

    func testOpenArchive() {
        
        // After opening the archive, the folder should contain a file
        // named 'version.txt' with the current version number of the
        // archive format.
        
        guard let directory = self.directory else { return }
        
        let archive = Archive(directory: directory)

        let wait = expectation(description: "Open Archive")
        archive.open {
            error in
            XCTAssertNil(error, "Failed to open the archive: \(error?.localizedDescription)")
            wait.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        
        XCTAssertEqual(archive.version, Archive.Setup.version)
        
        let versionFileURL = directory.appendingPathComponent("version.txt")
        let versionFileText = try? String(contentsOf: versionFileURL)
        XCTAssertNotNil(versionFileText)
        
        guard let text = versionFileText else { return }
        
        let version = Int(text)
        XCTAssertEqual(version, Archive.Setup.version)
    }
}
