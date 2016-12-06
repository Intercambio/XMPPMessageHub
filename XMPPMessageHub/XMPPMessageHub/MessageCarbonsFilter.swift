//
//  MessageCarbonsFilter.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import CoreXMPP

class MessageCarbonsFilter: MessageFilter {
    
    enum Direction {
        case received
        case sent
    }
    
    let direction: Direction
    init(direction: Direction) {
        self.direction = direction
    }
    
    func apply(to document: PXDocument, with metadata: Metadata) throws -> MessageFilter.Result {
        let namespaces: [String:String] = [
            "a":"jabber:client",
            "b":"urn:xmpp:carbons:2",
            "c":"urn:xmpp:forward:0"
        ]
        
        let xpath = direction == .received ? "./b:received/c:forwarded/a:message" : "./b:sent/c:forwarded/a:message"
        let jidAttribute = direction == .received ? "to" : "from"
        
        guard
            let message = document.root.nodes(forXPath: xpath, usingNamespaces: namespaces).first as? PXElement,
            let newDocument = PXDocument(element: message)
            else { return (document: document, metadata: metadata) }
        
        guard
            let envelopeFromString = document.root.value(forAttribute: "from") as? String,
            let envelopeFrom = JID(envelopeFromString)
            else { return (document: document, metadata: metadata) }
        
        guard
            let jidString = message.value(forAttribute: jidAttribute) as? String,
            let jid = JID(jidString)
            else { return (document: document, metadata: metadata) }
        
        guard
            jid.bare() == envelopeFrom.bare()
            else { return (document: document, metadata: metadata) }
        
        var newMetadata = metadata
        newMetadata.forwarded = true
        
        return (document: newDocument, metadata: newMetadata)
    }
}
