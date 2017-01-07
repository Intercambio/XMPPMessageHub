//
//  MessageArchivePartition.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 07.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import Foundation

struct MessageArchivePartition {
    let first: MessageArchvieID
    let last: MessageArchvieID
    let timestamp: Date
    let stable: Bool
    let complete: Bool
    let archvieIDs: Set<MessageArchvieID>
    let before: MessageArchvieID?
}
