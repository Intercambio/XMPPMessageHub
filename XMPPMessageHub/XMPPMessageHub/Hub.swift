//
//  Hub.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation
import PureXML

public class Hub: NSObject, ArchvieManager, MessageHandler, ConnectionHandler {
    
    public weak var messageHandler: MessageHandler? {
        didSet {
            outboundMessageHandler.messageHandler = messageHandler
        }
    }
    
    public weak var iqHandler: IQHandler? {
        didSet {
            messageCarbonsDispatchHandler.iqHandler = iqHandler
        }
    }
    
    fileprivate let inboundMessageHandler: InboundMesageHandler
    fileprivate let outboundMessageHandler: OutboundMessageHandler
    fileprivate let messageCarbonsDispatchHandler: MessageCarbonsDispatchHandler
    
    fileprivate let queue: DispatchQueue
    
    private let archvieManager: ArchvieManager
    private var archiveByAccount: [JID:Archive] = [:]
    
    required public init(archvieManager: ArchvieManager) {
        inboundMessageHandler = InboundMesageHandler(archvieManager: archvieManager)
        outboundMessageHandler = OutboundMessageHandler()
        messageCarbonsDispatchHandler = MessageCarbonsDispatchHandler()
        queue = DispatchQueue(label: "Hub", attributes: [.concurrent])
        self.archvieManager = archvieManager
        super.init()
        inboundMessageHandler.delegate = self
        outboundMessageHandler.delegate = self
        messageCarbonsDispatchHandler.delegate = self
    }
    
    // MARK: - ArchvieManager
    
    public func archive(for account: JID, create: Bool, completion: @escaping (Archive?, Error?) -> Void) -> Void {
        queue.async(flags: [.barrier]) {
            if let archive = self.archiveByAccount[account] {
                completion(ArchiveProxy(archive: archive, delegate: self), nil)
            } else {
                self.archvieManager.archive(for: account, create: create) {
                    archive, error in
                    self.archiveByAccount[account] = archive
                    completion(archive != nil ? ArchiveProxy(archive: archive!, delegate: self) : nil, error)
                }
            }
        }
    }
    
    public func deleteArchive(for account: JID, completion: @escaping ((Error?) -> Void)) -> Void {
        queue.async(flags: [.barrier]) {
            self.archiveByAccount[account] = nil
            self.archvieManager.deleteArchive(for: account, completion: completion)
        }
    }
    
    // MARK: - MessageHandler
    
    public func handleMessage(_ stanza: MessageStanza, completion: ((Error?) -> Void)?) {
        self.inboundMessageHandler.handleMessage(stanza, completion: completion)
    }
    
    // MARK: - DispatcherHandler
    
    public func didConnect(_ jid: JID, resumed: Bool) {
        self.messageCarbonsDispatchHandler.didConnect(jid, resumed: resumed)
    }
    
    public func didDisconnect(_ jid: JID) {
    }
}

extension Hub: ArchiveProxyDelegate, InboundMesageHandlerDelegate, OutboundMessageHandlerDelegate, MessageCarbonsDispatchHandlerDelegate {
    
    // MARK: - ArchiveProxyDelegate
    
    func archiveProxy(_ proxy: ArchiveProxy, didInsert message: Message, with document: PXDocument) {
        queue.async(flags: [.barrier]) {
            self.outboundMessageHandler.send(message, with: document, in: proxy.archive)
        }
    }
    
    // MARK: - InboundMesageHandlerDelegate
    
    func inboundMessageHandler(_ handler: InboundMesageHandler, didReceive message: Message, userInfo: [AnyHashable : Any]) {
        NSLog("Did receive message: \(message.messageID)")
    }
    
    // MARK: - OutboundMessageHandlerDelegate
    
    func outboundMessageHandler(_ handler: OutboundMessageHandler, didSent message: Message) {
        NSLog("Did send message: \(message.messageID)")
    }
    
    func outboundMessageHandler(_ handler: OutboundMessageHandler, failedToSend message: Message, with error: Error) {
        NSLog("Failed to send message: \(message.messageID) with error: \(error.localizedDescription)")
    }
    
    // MARK: - MessageCarbonsDispatchHandlerDelegate
    
    func messageCarbonsDispatchHandler(_ handler: MessageCarbonsDispatchHandler, didEnableFor account: JID) {
        NSLog("Did enable message carbons for: \(account.stringValue)")
    }
    
    func messageCarbonsDispatchHandler(_ handler: MessageCarbonsDispatchHandler, failedToEnableFor account: JID, wirth error: Error) {
        NSLog("Failed to enable message carbons for: \(account.stringValue) with error: \(error)")
    }
}
