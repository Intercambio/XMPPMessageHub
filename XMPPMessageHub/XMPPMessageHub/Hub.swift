//
//  Hub.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import CoreXMPP
import PureXML

extension NSNotification.Name {
    public static let HubDidAddMessageNotification = Notification.Name(rawValue: "XMPPMessageHubDidAddMessageNotification")
    public static let HubDidUpdateMessageNotification = Notification.Name(rawValue: "XMPPMessageHubDidUpdateMessageNotification")
}

public enum HubError: Error {
    case invalidDocument
}

public class Hub: NSObject, ArchvieManager, ArchiveProxyDelegate, MessageHandler, DispatcherHandler, InboundMesageHandlerDelegate, OutboundMessageHandlerDelegate, MessageCarbonsDispatchHandlerDelegate {
    
    public static let MessageKey = "XMPPMessageHubMessageKey"
    
    public weak var messageHandler: MessageHandler? { didSet { outboundMessageHandler.messageHandler = messageHandler } }
    public weak var iqHandler: IQHandler? { didSet { messageCarbonsDispatchHandler.iqHandler = iqHandler } }
    
    private var archiveByAccount: [JID:Archive] = [:]
    
    private let archvieManager: ArchvieManager
    private let inboundMessageHandler: InboundMesageHandler
    private let outboundMessageHandler: OutboundMessageHandler
    private let messageCarbonsDispatchHandler: MessageCarbonsDispatchHandler
    private let queue: DispatchQueue
    
    required public init(archvieManager: ArchvieManager, inboundFilter: [MessageFilter] = [], outboundFilter: [MessageFilter] = []) {
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
    
    // MARK: - ArchiveProxyDelegate
    
    func archiveProxy(_ proxy: ArchiveProxy, didInsert message: Message, with document: PXDocument) {
        queue.async(flags: [.barrier]) {
            self.outboundMessageHandler.send(message, with: document, in: proxy.archive)
        }
    }
    
    // MARK: - InboundMesageHandlerDelegate
    
    func inboundMessageHandler(_ handler: InboundMesageHandler, didReceive message: Message) {
        queue.async {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name.HubDidAddMessageNotification,
                    object: self,
                    userInfo: [Hub.MessageKey:message])
            }
        }
    }
    
    // MARK: - OutboundMessageHandlerDelegate
    
    func outboundMessageHandler(_ handler: OutboundMessageHandler, didSent message: Message) {
        queue.async {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name.HubDidUpdateMessageNotification,
                    object: self,
                    userInfo: [Hub.MessageKey:message])
            }
        }
    }
    
    func outboundMessageHandler(_ handler: OutboundMessageHandler, failedToSend message: Message, with error: Error) {
        queue.async {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name.HubDidUpdateMessageNotification,
                    object: self,
                    userInfo: [Hub.MessageKey:message])
            }
        }
    }
    
    // MARK: - MessageCarbonsDispatchHandlerDelegate
    
    func messageCarbonsDispatchHandler(_ handler: MessageCarbonsDispatchHandler, didEnableFor account: JID) {
        NSLog("Did enable message carbons for: \(account.stringValue)")
    }
    
    func messageCarbonsDispatchHandler(_ handler: MessageCarbonsDispatchHandler, failedToEnableFor account: JID, wirth error: Error) {
        NSLog("Failed to enable message carbons for: \(account.stringValue) with error: \(error)")
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
