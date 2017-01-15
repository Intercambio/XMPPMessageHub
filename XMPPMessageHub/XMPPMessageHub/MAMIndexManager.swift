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
    
    func add(_ partition: MAMIndexPartition, for account: JID) throws {
        guard
            partition.stable == true
        else { return }
        
        var index = try getIndex(for: account)
        index = index.add(partition)
        try setIndex(index, for: account)
    }
    
    func nextArchvieID(for account: JID) throws -> MessageArchiveID? {
        let index = try getIndex(for: account)
        return index.canLoadMore == true ? index.nextArchiveID : nil
    }
    
    func canLoadMoreMessages(for account: JID) throws -> Bool {
        let index = try getIndex(for: account)
        return index.canLoadMore
    }
    
    private func getIndex(for account: JID) throws -> MAMIndex {
        do {
            let url = indexFileURL(for: account)
            let data = try Data(contentsOf: url)
            
            guard
                let index: MAMIndex = NSKeyedUnarchiver.unarchiveStructure(with: data)
            else {
                return MAMIndex(partitions: [])
            }
            
            return index
        } catch {
            return MAMIndex(partitions: [])
        }
    }
    
    private func setIndex(_ index: MAMIndex, for account: JID) throws {
        let url = indexFileURL(for: account)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let data = NSKeyedArchiver.archivedData(withStructure: index)
        try data.write(to: url)
    }
    
    private func indexFileURL(for account: JID) -> URL {
        let name = account.stringValue
        let directory = self.directory.appendingPathComponent(name, isDirectory: true)
        return directory.appendingPathComponent("index", isDirectory: false)
    }
}
