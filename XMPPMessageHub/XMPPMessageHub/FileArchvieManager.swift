//
//  FileArchvieManager.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation

public class FileArchvieManager: ArchvieManager {
    
    public let directory: URL
    
    private typealias CompletionHandler = (Archive?, Error?) -> Void
    
    private struct PendingArchive {
        let archvie: Archive
        var handler: [CompletionHandler]
    }
    
    private let queue: DispatchQueue
    private var archiveByAccount: [JID:FileArchive] = [:]
    private var pendingArchivesByAccount: [JID:PendingArchive] = [:]
    
    required public init(directory: URL) {
        self.directory = directory
        queue = DispatchQueue(
            label: "ArchvieManager",
            attributes: [])
    }
    
    public func archive(for account: JID, create: Bool = false, completion: @escaping (Archive?, Error?) -> Void) {
        queue.async {
            do {
                if let archvie = self.archiveByAccount[account] {
                    completion(archvie, nil)
                } else if var pendingArchvie = self.pendingArchivesByAccount[account] {
                    pendingArchvie.handler.append(completion)
                } else {
                    let archvie = try self.openArchive(for: account, create: create)
                    let pendingArchvie = PendingArchive(archvie: archvie, handler: [completion])
                    self.pendingArchivesByAccount[account] = pendingArchvie
                    self.open(archvie)
                }
            } catch {
                completion(nil, error)
            }
        }
    }
    
    public func deleteArchive(for account: JID, completion: @escaping ((Error?) -> Void) = {_ in}) {
        queue.async {
            do {
                if let archive = self.archiveByAccount[account] {
                    self.archiveByAccount[account] = nil
                    archive.close()
                } else if let pendingArchvie = self.pendingArchivesByAccount[account] {
                    self.pendingArchivesByAccount[account] = nil
                    for completion in pendingArchvie.handler {
                        completion(nil, ArchvieManagerError.deleted)
                    }
                }
                try self.deleteArchvie(for: account)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    private func open(_ archive: FileArchive) {
        archive.open { (error) in
            self.queue.async {
                if let pendingArchvie = self.pendingArchivesByAccount[archive.account] {
                    self.pendingArchivesByAccount[archive.account] = nil
                    if error == nil {
                        self.archiveByAccount[archive.account] = archive
                    }
                    for completion in pendingArchvie.handler {
                        completion(archive, error)
                    }
                }
            }
        }
    }
    
    private func openArchive(for account: JID, create: Bool) throws -> FileArchive {
        let location = archiveLocation(for: account)
        if create == false && FileManager.default.fileExists(atPath: location.path, isDirectory: nil) == false {
            throw ArchvieManagerError.doesNotExist
        }
        try FileManager.default.createDirectory(
            at: location,
            withIntermediateDirectories: true,
            attributes: nil)
        return FileArchive(directory: location, account: account)
    }
    
    private func deleteArchvie(for account: JID) throws {
        let location = archiveLocation(for: account)
        try FileManager.default.removeItem(at: location)
    }
    
    private func archiveLocation(for account: JID) -> URL {
        let name = account.stringValue
        return directory.appendingPathComponent(name, isDirectory: true)
    }
}
