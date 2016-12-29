//
//  OutboundMessageHandler.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 06.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML
import XMPPFoundation

protocol OutboundMessageHandlerDelegate: class {
    func outboundMessageHandler(_ handler: OutboundMessageHandler, didSent message: Message) -> Void
    func outboundMessageHandler(_ handler: OutboundMessageHandler, failedToSend message: Message, with error: Error) -> Void
}

class OutboundMessageHandler {
    
    public weak var delegate: OutboundMessageHandlerDelegate?
    
    private var messagesBeeingTransmitted: [MessageID] = []
    private let queue: DispatchQueue
    private let dispatcher: Dispatcher
    
    required init(dispatcher: Dispatcher) {
        self.dispatcher = dispatcher
        queue = DispatchQueue(
            label: "OutboundMessageHandler",
            attributes: [])
    }
    
    func send(_ message: Message, with document: PXDocument, in archive: Archive) {
        queue.async {
            guard
                let stanza = document.root as? MessageStanza,
                self.messagesBeeingTransmitted.contains(message.messageID) == false
                else { return }
            
            self.messagesBeeingTransmitted.append(message.messageID)
            self.dispatcher.handleMessage(stanza) { error in
                self.queue.async(flags: [.barrier]) {
                    if let idx = self.messagesBeeingTransmitted.index(of: message.messageID) {
                        self.messagesBeeingTransmitted.remove(at: idx)
                    }
                    do {
                        let now = Date()
                        let message = try archive.update(
                            transmitted: error == nil ? now :  nil,
                            error: error as? TransmissionError,
                            for: message.messageID)
                        
                        if let error = error {
                            self.delegate?.outboundMessageHandler(self, failedToSend: message, with: error)
                        } else {
                            self.delegate?.outboundMessageHandler(self, didSent: message)
                        }
                        
                    } catch {
                        NSLog("Failed to update message metadata: \(error)")
                    }
                }
            }
        }
    }
}
