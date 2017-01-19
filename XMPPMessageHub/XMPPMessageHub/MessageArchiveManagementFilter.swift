//
//  MessageArchiveManagementFilter.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 25.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
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
