//
//  MessageFilter.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
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
