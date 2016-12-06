//
//  MessageFilter.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML

public protocol MessageFilter {
    typealias Result = (document: PXDocument, metadata: Metadata)
    func apply(to document: PXDocument, with metadata: Metadata) throws -> Result
}
