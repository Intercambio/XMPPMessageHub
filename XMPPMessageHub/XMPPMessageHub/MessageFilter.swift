//
//  MessageFilter.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation

public protocol MessageFilter {
    typealias Result = (message: MessageStanza, metadata: Metadata, userInfo: [AnyHashable: Any])
    func apply(to message: MessageStanza, with metadata: Metadata, userInfo: [AnyHashable: Any]) throws -> Result?
    
    var optional: MessageFilter { get }
    var inverte: MessageFilter { get }
}

extension MessageFilter {
    public var optional: MessageFilter {
        return OptionalMessageFilter(filter: self)
    }
    public var inverte: MessageFilter {
        return InvertedMessageFilter(filter: self)
    }
}

class OptionalMessageFilter: MessageFilter {
    
    let filter: MessageFilter
    init(filter: MessageFilter) {
        self.filter = filter
    }
    
    func apply(to message: MessageStanza, with metadata: Metadata, userInfo: [AnyHashable: Any]) throws -> MessageFilter.Result? {
        guard
            let result = try filter.apply(to: message, with: metadata, userInfo: userInfo)
        else { return (message: message, metadata: metadata, userInfo: userInfo) }
        
        return result
    }
    
    var optional: MessageFilter { return self }
}

class InvertedMessageFilter: MessageFilter {
    
    let filter: MessageFilter
    init(filter: MessageFilter) {
        self.filter = filter
    }
    
    func apply(to message: MessageStanza, with metadata: Metadata, userInfo: [AnyHashable: Any]) throws -> MessageFilter.Result? {
        guard
            try filter.apply(to: message, with: metadata, userInfo: userInfo) != nil
        else { return (message: message, metadata: metadata, userInfo: userInfo) }
        
        return nil
    }
    
    var inverte: MessageFilter { return self }
}
