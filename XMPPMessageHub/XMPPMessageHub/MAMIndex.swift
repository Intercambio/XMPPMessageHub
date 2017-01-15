//
//  MAMIndex.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
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
