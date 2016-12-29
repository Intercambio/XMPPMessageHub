//
//  MessageCarbonsFilter.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import XMPPFoundation

class MessageCarbonsFilter: MessageFilter {
    
    enum Direction {
        case received
        case sent
    }
    
    let direction: Direction
    init(direction: Direction) {
        self.direction = direction
    }
    
    func apply(to message: MessageStanza, with metadata: Metadata, userInfo: [AnyHashable:Any]) throws -> MessageFilter.Result? {
        let namespaces: [String:String] = [
            "a":"jabber:client",
            "b":"urn:xmpp:carbons:2",
            "c":"urn:xmpp:forward:0"
        ]
        
        let xpath = direction == .received ? "./b:received/c:forwarded/a:message" : "./b:sent/c:forwarded/a:message"

        guard
            let envelopeFrom = message.from,
            let forwardedMessage = message.nodes(forXPath: xpath, usingNamespaces: namespaces).first as? MessageStanza,
            let jid = direction == .received ? forwardedMessage.to : forwardedMessage.from,
            jid.bare() == envelopeFrom.bare()
            else { return nil }

        var newMetadata = metadata
        newMetadata.isCarbonCopy = true
        
        return (message: forwardedMessage, metadata: newMetadata, userInfo: userInfo)
    }
}
