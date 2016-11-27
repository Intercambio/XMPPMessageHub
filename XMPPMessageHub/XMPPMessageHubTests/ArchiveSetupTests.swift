//
//  ArchiveSetupTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 21.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
@testable import XMPPMessageHub

class ArchiveSetupTests: TestCase {
    
    func testSetupArchive() {
        guard let directory = self.directory else { return }
        
        let setup = Archive.Setup(directory: directory)
        let store = try? setup.run()
        
        XCTAssertEqual(setup.version, 1)
        XCTAssertNotNil(store)
        
        let messageDirectory = directory.appendingPathComponent("messages", isDirectory: true)
        let fileManager = FileManager.default
        
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: messageDirectory.path,
                                            isDirectory: &isDirectory)
        XCTAssertTrue(exists)
    }
}
