//
//  MAMIndexManager.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 15.01.17.
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
