//
//  FileArchvieManager.swift
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

import Foundation
import XMPPFoundation

public class FileArchvieManager: ArchiveManager {
    
    public let directory: URL
    
    private typealias CompletionHandler = (Archive?, Error?) -> Void
    
    private struct PendingArchive {
        let archvie: Archive
        var handler: [CompletionHandler]
    }
    
    private let queue: DispatchQueue
    private var archiveByAccount: [JID: FileArchive] = [:]
    private var pendingArchivesByAccount: [JID: PendingArchive] = [:]
    
    public required init(directory: URL) {
        self.directory = directory
        queue = DispatchQueue(
            label: "ArchvieManager",
            attributes: []
        )
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
    
    public func deleteArchive(for account: JID, completion: @escaping ((Error?) -> Void) = { _ in }) {
        queue.async {
            do {
                if let archive = self.archiveByAccount[account] {
                    self.archiveByAccount[account] = nil
                    archive.close()
                } else if let pendingArchvie = self.pendingArchivesByAccount[account] {
                    self.pendingArchivesByAccount[account] = nil
                    for completion in pendingArchvie.handler {
                        completion(nil, ArchiveManagerError.deleted)
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
        archive.open { error in
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
            throw ArchiveManagerError.doesNotExist
        }
        try FileManager.default.createDirectory(
            at: location,
            withIntermediateDirectories: true,
            attributes: nil
        )
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
