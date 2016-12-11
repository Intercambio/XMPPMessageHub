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

public class Hub: NSObject, ArchvieManager, MessageHandler, DispatcherHandler {
    
    public static let MessageKey = "XMPPMessageHubMessageKey"
    
    public weak var messageHandler: MessageHandler? { didSet { outboundMessageHandler.messageHandler = messageHandler } }
    public weak var iqHandler: IQHandler? { didSet { messageCarbonsDispatchHandler.iqHandler = iqHandler } }
    
    fileprivate let archvieManager: ArchvieManager
    fileprivate let inboundMessageHandler: InboundMesageHandler
    fileprivate let outboundMessageHandler: OutboundMessageHandler
    fileprivate let messageCarbonsDispatchHandler: MessageCarbonsDispatchHandler
    fileprivate let queue: DispatchQueue
    
    private var archiveByAccount: [JID:Archive] = [:]
    
    required public init(archvieManager: ArchvieManager) {
        let inboundFilter: [MessageFilter] = [
            MessageCarbonsFilter(direction: .received),
            MessageCarbonsFilter(direction: .sent)
        ]
        let outboundFilter: [MessageFilter] = [
        ]
        self.archvieManager = archvieManager
        self.inboundMessageHandler = InboundMesageHandler(archvieManager: archvieManager, inboundFilter: inboundFilter)
        self.outboundMessageHandler = OutboundMessageHandler(outboundFilter: outboundFilter)
        self.messageCarbonsDispatchHandler = MessageCarbonsDispatchHandler()
        queue = DispatchQueue(
            label: "Hub",
            attributes: [.concurrent])
        super.init()
        self.inboundMessageHandler.delegate = self
        self.outboundMessageHandler.delegate = self
        self.messageCarbonsDispatchHandler.delegate = self
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
    
    public func handleMessage(_ document: PXDocument,
                              completion: ((Error?) -> Void)?) {
        queue.async {
           self.inboundMessageHandler.handleMessage(document, completion: completion)
        }
    }
    
    // MARK: - DispatcherHandler
    
    public func didAddConnection(_ jid: JID) {
        queue.async {
            
        }
    }
    
    public func didRemoveConnection(_ jid: JID) {
        queue.async {
            
        }
    }
    
    public func didConnect(_ jid: JID, resumed: Bool) {
        queue.async {
            self.messageCarbonsDispatchHandler.didConnect(jid, resumed: resumed)
        }
    }
    
    public func didDisconnect(_ jid: JID) {
        queue.async {
            
        }
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
    
    func inboundMessageHandler(_ handler: InboundMesageHandler, didReceive message: Message) {
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
