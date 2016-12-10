//
//  ArchiveManager.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation

public enum ArchvieManagerError: Error {
    case doesNotExist
    case deleted
}

public protocol ArchvieManager {
    func archive(for account: JID, create: Bool, completion: @escaping (Archive?, Error?) -> Void) -> Void
    func deleteArchive(for account: JID, completion: @escaping ((Error?) -> Void)) -> Void
}

