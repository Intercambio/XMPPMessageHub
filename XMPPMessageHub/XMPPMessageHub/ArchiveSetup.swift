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
        
        var version: Int {
            get {
                return readCurrentVersion()
            }
        }
        
        let directory: URL
        required init(directory: URL) {
            self.directory = directory
        }
        
        var messageDirectory: URL {
            return directory.appendingPathComponent("messages", isDirectory: true)
        }
        
        func run() throws -> ArchiveDocumentStore {
            if readCurrentVersion() == 0 {
                try createMessageDirectory()
                try writeCurrentVersion(Setup.version)
            }
            return ArchiveFileDocumentStore(directory: messageDirectory)
        }
        
        private func createMessageDirectory() throws {
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: messageDirectory,
                withIntermediateDirectories: false,
                attributes: [:])
        }
        
        private func readCurrentVersion() -> Int {
            let url = directory.appendingPathComponent("version.txt")
            do {
                let versionText = try String(contentsOf: url)
                guard let version = Int(versionText) else { return 0 }
                return version
            } catch {
                return 0
            }
        }
        
        private func writeCurrentVersion(_ version: Int) throws {
            let url = directory.appendingPathComponent("version.txt")
            let versionData = String(version).data(using: .utf8)
            try versionData?.write(to: url)
        }
    }
}
