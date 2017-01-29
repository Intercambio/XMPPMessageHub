//
//  MAMIndex.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.01.17.
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

struct MAMIndex {
    
    let partitions: [MAMIndexPartition]
    
    var nextArchiveID: MessageArchiveID? {
        return partitions.first?.first
    }
    
    var canLoadMore: Bool {
        guard
            let partition = partitions.last, partitions.count == 1
        else { return true }
        return partition.complete == false
    }
    
    func add(_ partition: MAMIndexPartition) -> MAMIndex {
        var mergedPartitions: [MAMIndexPartition] = []
        var currentPartition: MAMIndexPartition? = partition
        for partition in partitions {
            guard
                let current = currentPartition
            else {
                mergedPartitions.append(partition)
                continue
            }
            switch current.merge(partition) {
            case (let recent, let other) where other == nil:
                currentPartition = recent
            case (let recent, let other):
                mergedPartitions.append(recent)
                currentPartition = other
            }
        }
        if let current = currentPartition {
            mergedPartitions.append(current)
        }
        return MAMIndex(partitions: mergedPartitions)
    }
}

extension MAMIndex: Dictionariable {
    init?(dictionaryRepresentation: NSDictionary?) {
        guard
            let values = dictionaryRepresentation,
            let partitionValues = values["partitions"] as? [NSDictionary]
        else { return nil }
        
        var partitions: [MAMIndexPartition] = []
        for v in partitionValues {
            guard
                let partition = MAMIndexPartition(dictionaryRepresentation: v)
            else { return nil }
            partitions.append(partition)
        }
        self.partitions = partitions
    }
    
    func dictionaryRepresentation() -> NSDictionary {
        var partitionValues: [NSDictionary] = []
        for partition in partitions {
            partitionValues.append(partition.dictionaryRepresentation())
        }
        return NSDictionary(dictionary: ["partitions": partitionValues])
    }
}
