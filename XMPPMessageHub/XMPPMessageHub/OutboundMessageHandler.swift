//
//  OutboundMessageHandler.swift
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
