//
//  MessageHub.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation
import PureXML

public class MessageHub: NSObject, ArchiveManager {
    
    fileprivate let inboundMessageHandler: InboundMesageHandler
    fileprivate let outboundMessageHandler: OutboundMessageHandler
    fileprivate let messageCarbonsHandler: MessageCarbonsHandler
    fileprivate let messageArchiveHandler: MessageArchiveHandler
    
    fileprivate let queue: DispatchQueue
    
    private let dispatcher: Dispatcher
    private let archvieManager: ArchiveManager
    private let indexManager: MAMIndexManager
    private var archiveByAccount: [JID: Archive] = [:]
    
    public required init(dispatcher: Dispatcher, directory: URL) {
        
        let archiveDirectory = directory.appendingPathComponent("archive", isDirectory: true)
        archvieManager = FileArchvieManager(directory: archiveDirectory)
        
        let mamDirectory = directory.appendingPathComponent("mam", isDirectory: true)
        indexManager = MAMIndexManager(directory: mamDirectory)
        
        inboundMessageHandler = InboundMesageHandler(dispatcher: dispatcher, archvieManager: archvieManager)
        outboundMessageHandler = OutboundMessageHandler(dispatcher: dispatcher, archvieManager: archvieManager)
        messageCarbonsHandler = MessageCarbonsHandler(dispatcher: dispatcher)
        messageArchiveHandler = MessageArchiveHandler(dispatcher: dispatcher, archvieManager: archvieManager, indexManager: indexManager)
        
        queue = DispatchQueue(label: "Hub", attributes: [.concurrent])
        
        self.dispatcher = dispatcher
        
        super.init()
        
        inboundMessageHandler.delegate = self
        outboundMessageHandler.delegate = self
        messageCarbonsHandler.delegate = self
    }
    
    // MARK: - ArchvieManager
    
    public func archive(for account: JID, create: Bool, completion: @escaping (Archive?, Error?) -> Void) {
        queue.async(flags: [.barrier]) {
            if let archive = self.archiveByAccount[account] {
                let proxy = ArchiveProxy(archive: archive, mam: self.messageArchiveHandler)
                proxy.delegate = self
                completion(proxy, nil)
            } else {
                self.archvieManager.archive(for: account, create: create) {
                    archive, error in
                    self.archiveByAccount[account] = archive
                    
                    if let archive = archive {
                        let proxy = ArchiveProxy(archive: archive, mam: self.messageArchiveHandler)
                        proxy.delegate = self
                        completion(proxy, error)
                    } else {
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    public func deleteArchive(for account: JID, completion: @escaping ((Error?) -> Void)) {
        queue.async(flags: [.barrier]) {
            self.archiveByAccount[account] = nil
            self.archvieManager.deleteArchive(for: account, completion: completion)
        }
    }
}

extension MessageHub: ArchiveProxyDelegate, InboundMesageHandlerDelegate, OutboundMessageHandlerDelegate, MessageCarbonsHandlerDelegate {
    
    // MARK: - ArchiveProxyDelegate
    
    func archiveProxy(_ proxy: ArchiveProxy, didInsert message: Message, with document: PXDocument) {
        queue.async(flags: [.barrier]) {
            self.outboundMessageHandler.send(message, with: document, in: proxy.archive)
        }
    }
    
    // MARK: - InboundMesageHandlerDelegate
    
    func inboundMessageHandler(_: InboundMesageHandler, didReceive message: Message, userInfo _: [AnyHashable: Any]) {
        NSLog("Did receive message: \(message.messageID)")
    }
    
    // MARK: - OutboundMessageHandlerDelegate
    
    func outboundMessageHandler(_: OutboundMessageHandler, didSent message: Message) {
        NSLog("Did send message: \(message.messageID)")
    }
    
    func outboundMessageHandler(_: OutboundMessageHandler, failedToSend message: Message, with error: Error) {
        NSLog("Failed to send message: \(message.messageID) with error: \(error.localizedDescription)")
    }
    
    // MARK: - MessageCarbonsDispatchDelegate
    
    func messageCarbonsHandler(_: MessageCarbonsHandler, didEnableFor account: JID) {
        NSLog("Did enable message carbons for: \(account.stringValue)")
    }
    
    func messageCarbonsHandler(_: MessageCarbonsHandler, failedToEnableFor account: JID, wirth error: Error) {
        NSLog("Failed to enable message carbons for: \(account.stringValue) with error: \(error)")
    }
}
