//
//  MAMIndexManager.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 15.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation

class MAMIndexManager {

    let directory: URL
    init(directory: URL) {
        self.directory = directory
    }
    
    func add(_ partition: MessageArchivePartition, for account: JID) throws {
        guard
            partition.stable == true
            else { return }

        var index = try getIndex(for: account)
        index = index.add(partition)
        try setIndex(index, for: account)
    }
    
    func nextArchvieID(for account: JID) throws -> MessageArchiveID? {
        let index = try getIndex(for: account)
        return index.nextArchiveID
    }
    
    func canLoadMoreMessages(for account: JID) throws -> Bool {
        let index = try getIndex(for: account)
        return index.canLoadMore
    }
    
    private func getIndex(for account: JID) throws -> MessageArchiveIndex {
        do {
            let url = indexFileURL(for: account)
            let data = try Data(contentsOf: url)
            
            guard
                let index: MessageArchiveIndex = NSKeyedUnarchiver.unarchiveStructure(with: data)
                else {
                    return MessageArchiveIndex(partitions: [])
            }
            
            return index
        } catch {
            return MessageArchiveIndex(partitions: [])
        }
    }
    
    private func setIndex(_ index: MessageArchiveIndex, for account: JID) throws {
        let url = indexFileURL(for: account)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: nil)
        let data = NSKeyedArchiver.archivedData(withStructure: index)
        try data.write(to: url)
    }
    
    private func indexFileURL(for account: JID) -> URL {
        let name = account.stringValue
        let directory = self.directory.appendingPathComponent(name, isDirectory: true)
        return directory.appendingPathComponent("index", isDirectory: false)
    }
}
