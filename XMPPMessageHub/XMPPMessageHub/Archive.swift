//
//  Archive.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 20.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import CoreXMPP
import Dispatch

public class Archive {

    public let directory: URL
    
    private let queue: DispatchQueue = DispatchQueue(label: "org.intercambio.XMPPMessageHub.Archive")
    required public init(directory: URL) {
        self.directory = directory
    }
    
    // MARK: - Open Archive
    
    public func open(completion: @escaping (Error?) ->Void) {
        queue.async {
            do {
                try self.open()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    private func open() throws {
        try setupArchive()
    }
    
    // Mark: - Setup
    
    private func setupArchive() throws {
        if let setup = Setup.makeSetup(from: readCurrentVersion(), directory: directory) {
            version = try setup.run()
            try writeCurrentVersion(version)
        }
    }
    
    // MARK: - Archive Version
    
    public private(set) var version: Int = 0
    
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
