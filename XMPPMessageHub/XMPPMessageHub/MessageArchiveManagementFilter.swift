//
//  MessageArchiveManagementFilter.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 25.12.16.
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
import ISO8601
import PureXML

class MessageArchiveManagementFilter: MessageFilter {
    
    private let dateFormatter: ISO8601.ISO8601DateFormatter = ISO8601DateFormatter()
    
    func apply(to message: MessageStanza, with metadata: Metadata, userInfo: [AnyHashable: Any]) throws -> MessageFilter.Result? {
        
        let namespaces = [
            "mam": "urn:xmpp:mam:1",
            "forward": "urn:xmpp:forward:0",
            "xmpp": "jabber:client",
            "delay": "urn:xmpp:delay"
        ]
        
        guard
            let result = message.nodes(forXPath: "./mam:result", usingNamespaces: namespaces).first as? PXElement
        else {
            return nil
        }
        
        guard
            let queryID = result.value(forAttribute: "queryid") as? String,
            let archiveID = result.value(forAttribute: "id") as? String,
            let delayElement = result.nodes(forXPath: "./forward:forwarded/delay:delay", usingNamespaces: namespaces).first as? PXElement,
            let timestampString = delayElement.value(forAttribute: "stamp") as? String,
            let timestamp = self.dateFormatter.date(from: timestampString),
            let originalMessage = result.nodes(forXPath: "./forward:forwarded/xmpp:message", usingNamespaces: namespaces).first as? MessageStanza
        else {
            throw NSError(
                domain: StanzaErrorDomain,
                code: StanzaErrorCode.undefinedCondition.rawValue,
                userInfo: nil
            )
        }
        
        var newMetadata = metadata
        newMetadata.created = timestamp
        newMetadata.transmitted = timestamp
        
        var newUserInfo = userInfo
        newUserInfo[MessageArchvieIDKey] = archiveID
        newUserInfo[MessageArchvieQueryIDKey] = queryID
        
        return (
            message: originalMessage,
            metadata: newMetadata,
            userInfo: newUserInfo
        )
    }
}
