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

class OutboundMessageHandler: ConnectionHandler {
    
    public weak var delegate: OutboundMessageHandlerDelegate?
    
    private var messagesBeeingTransmitted: [MessageID] = []
    private let queue: DispatchQueue
    private let dispatcher: Dispatcher
    private let archvieManager: ArchiveManager
    
    required init(dispatcher: Dispatcher, archvieManager: ArchiveManager) {
        self.dispatcher = dispatcher
        self.archvieManager = archvieManager
        queue = DispatchQueue(
            label: "OutboundMessageHandler",
            attributes: []
        )
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
                        if let transmissionError = error as? NSError {
                            var updatedMessage = message
                            if transmissionError.domain != DispatcherErrorDomain &&
                                transmissionError.code != DispatcherErrorCode.noRoute.rawValue {
                                updatedMessage = try archive.update(
                                    transmitted: nil,
                                    error: transmissionError,
                                    for: message.messageID
                                )
                            }
                            self.delegate?.outboundMessageHandler(self, failedToSend: updatedMessage, with: transmissionError)
                        } else {
                            let message = try archive.update(
                                transmitted: Date(),
                                error: nil,
                                for: message.messageID
                            )
                            self.delegate?.outboundMessageHandler(self, didSent: message)
                        }
                    } catch {
                        NSLog("Failed to update message metadata: \(error)")
                    }
                    
                }
            }
        }
    }
    
    func resendPendignMessages(for account: JID) {
        queue.async {
            self.archvieManager.archive(for: account, create: false) { archive, error in
                guard
                    let accountArchvie = archive
                else {
                    return
                }
                do {
                    for message in try accountArchvie.pending() {
                        let document = try accountArchvie.document(for: message.messageID)
                        self.send(message, with: document, in: accountArchvie)
                    }
                } catch {
                    NSLog("Failed to resend pending messages: \(error)")
                }
            }
        }
    }
    
    // MARK: - ConnectionHandler
    
    func didConnect(_ JID: JID, resumed _: Bool, features _: [Feature]?) {
        resendPendignMessages(for: JID)
    }
    
    func didDisconnect(_: JID) {
        
    }
}
