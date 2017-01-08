//
//  MessageArchiveIndex.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import Foundation

struct MessageArchiveIndex {

    let partitions: [MessageArchivePartition]
    
    var nextArchiveID: MessageArchiveID? {
        return partitions.first?.last
    }
    
    var canLoadMore: Bool {
        guard
            let partition = partitions.last, partitions.count == 1
            else { return true }
        return partition.complete == false
    }
    
    func add(_ partition: MessageArchivePartition) -> MessageArchiveIndex {
        var mergedPartitions: [MessageArchivePartition] = []
        var currentPartition: MessageArchivePartition? = partition
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
        return MessageArchiveIndex(partitions: mergedPartitions)
    }
}
