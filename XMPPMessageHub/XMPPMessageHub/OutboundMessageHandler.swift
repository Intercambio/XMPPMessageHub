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
    
    public weak var messageHandler: MessageHandler?
    public weak var delegate: OutboundMessageHandlerDelegate?
    
    private var messagesBeeingTransmitted: [MessageID] = []
    
    private let queue: DispatchQueue
    private let outboundFilter: [MessageFilter]
    
    required init(outboundFilter: [MessageFilter]) {
        self.outboundFilter = outboundFilter
        queue = DispatchQueue(
            label: "OutboundMessageHandler",
            attributes: [.concurrent])
    }
    
    func send(_ message: Message, with document: PXDocument, in archive: Archive) {
        queue.async(flags: [.barrier]) {
            guard
                self.messagesBeeingTransmitted.contains(message.messageID) == false,
                let handler = self.messageHandler
                else { return }
            
            do {
                let initial: MessageFilter.Result? = (document: document, metadata: message.metadata, userInfo: [:])
                let result = try self.outboundFilter.reduce(initial) { input, filter in
                    guard
                        let result = input
                        else { return nil }
                    return try filter.apply(to: result.document, with: result.metadata, userInfo: result.userInfo)
                }
                
                if let result = result {
                    self.messagesBeeingTransmitted.append(message.messageID)
                    handler.handleMessage(result.document) { error in
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
            } catch {
                NSLog("Failed to apply outbound filter: \(error)")
            }
        }
    }
}
