//
//  MessageHub.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 04.12.16.
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
import XMPPFoundation
import PureXML

public class MessageHub: NSObject {
    
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
    
    public func archive(for account: JID, completion: @escaping (Archive?, Error?) -> Void) {
        queue.async(flags: [.barrier]) {
            if let archive = self.archiveByAccount[account] {
                let proxy = ArchiveProxy(archive: archive, mam: self.messageArchiveHandler)
                proxy.delegate = self
                completion(proxy, nil)
            } else {
                self.archvieManager.archive(for: account, create: true) {
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
    
    public func deleteResources(for account: JID, completion: ((Error?) -> Void)?) {
        queue.async {
            self.archiveByAccount[account] = nil
            self.indexManager.deleteIndex(for: account)
            self.archvieManager.deleteArchive(for: account) { (error) in
                completion?(error)
            }
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
