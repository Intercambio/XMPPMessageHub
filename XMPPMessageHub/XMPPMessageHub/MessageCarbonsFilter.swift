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

class MessageCarbonsReceivedFilter: MessageFilter {
    
    func apply(to document: PXDocument, with metadata: Metadata) throws -> MessageFilter.Result {
        let namespaces: [String:String] = [
            "a":"jabber:client",
            "b":"urn:xmpp:carbons:2",
            "c":"urn:xmpp:forward:0"
        ]
        
        guard
            let message = document.root.nodes(forXPath: "./b:received/c:forwarded/a:message", usingNamespaces: namespaces).first as? PXElement,
            let newDocument = PXDocument(element: message)
            else { return (document: document, metadata: metadata) }
        
        guard
            let envelopeFromString = document.root.value(forAttribute: "from") as? String,
            let envelopeFrom = JID(envelopeFromString)
            else { return (document: document, metadata: metadata) }
        
        guard
            let toString = message.value(forAttribute: "to") as? String,
            let to = JID(toString)
            else { return (document: document, metadata: metadata) }
        
        guard
            to.bare() == envelopeFrom.bare()
            else { return (document: document, metadata: metadata) }
        
        var newMetadata = metadata
        newMetadata.forwarded = true
        
        return (document: newDocument, metadata: newMetadata)
    }
}

class MessageCarbonsSentFilter: MessageFilter {
    func apply(to document: PXDocument, with metadata: Metadata) throws -> MessageFilter.Result {
        let namespaces: [String:String] = [
            "a":"jabber:client",
            "b":"urn:xmpp:carbons:2",
            "c":"urn:xmpp:forward:0"
        ]
        
        guard
            let message = document.root.nodes(forXPath: "./b:sent/c:forwarded/a:message", usingNamespaces: namespaces).first as? PXElement,
            let newDocument = PXDocument(element: message)
            else { return (document: document, metadata: metadata) }
        
        guard
            let envelopeFromString = document.root.value(forAttribute: "from") as? String,
            let envelopeFrom = JID(envelopeFromString)
            else { return (document: document, metadata: metadata) }
        
        guard
            let fromString = message.value(forAttribute: "from") as? String,
            let from = JID(fromString)
            else { return (document: document, metadata: metadata) }
        
        guard
            from.bare() == envelopeFrom.bare()
            else { return (document: document, metadata: metadata) }
        
        var newMetadata = metadata
        newMetadata.forwarded = true
        
        return (document: newDocument, metadata: newMetadata)
    }
}
