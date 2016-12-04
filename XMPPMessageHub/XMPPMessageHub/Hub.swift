//
//  Hub.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation

public class Hub {
    
    let archvieManager: ArchvieManager
    
    private let queue: DispatchQueue
    
    required public init(archvieManager: ArchvieManager) {
        self.archvieManager = archvieManager
        queue = DispatchQueue(
            label: "Hub",
            attributes: [.concurrent])
    }
}
