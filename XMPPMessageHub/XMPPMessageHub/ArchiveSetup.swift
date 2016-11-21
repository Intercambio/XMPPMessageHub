//
//  ArchiveSetup.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 21.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation

extension Archive {
    
    class Setup {
        
        static let version: Int = 1
        
        class func makeSetup(from current: Int, directory url: URL) -> Setup? {
            if current == 0 {
                return Setup(directory: url)
            } else {
                return nil
            }
        }
        
        let directory: URL
        required init(directory: URL) {
            self.directory = directory
        }
        
        func run() throws -> Int {
            try createMessageDirectory()
            return Setup.version
        }
        
        private func createMessageDirectory() throws {
            let url = directory.appendingPathComponent("messages", isDirectory: true)
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: false,
                attributes: [:])
        }
    }
}
