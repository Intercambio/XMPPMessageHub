//
//  TestDispatcher.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 09.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation

class TestDispatcher: Dispatcher {
    
    func send(_ message: MessageStanza, completion: ((Error?)->Void)?) {
        let group = DispatchGroup()
        for handler in handlers.allObjects {
            if let messageHandler = handler as? MessageHandler {
                group.enter()
                messageHandler.handleMessage(message, completion: { (error) in
                    group.leave()
                })
            }
        }
        group.notify(queue: DispatchQueue.main) {
            completion?(nil)
        }
    }
    
    func connect(_ JID: JID, resumed: Bool = false, features: [Feature]? = nil) {
        for handler in handlers.allObjects {
            if let connectionHandler = handler as? ConnectionHandler {
                connectionHandler.didConnect(JID, resumed: resumed, features: features)
            }
        }
    }
    
    let handlers: NSHashTable = NSHashTable<Handler>.weakObjects()
    
    func add(_ handler: Handler) {
        add(handler, withIQQueryQNames: nil, features: nil)
    }
    
    func add(_ handler: Handler, withIQQueryQNames queryQNames: [PXQName]?, features: [Feature]?) {
        handlers.add(handler)
    }
    
    func remove(_ handler: Handler) {
        handlers.remove(handler)
    }
    
    var presenceHandler: ((PresenceStanza, ((Error?) -> Void)?) -> Void)?
    public func handlePresence(_ stanza: PresenceStanza, completion: ((Error?) -> Swift.Void)? = nil) {
        presenceHandler?(stanza, completion)
    }
    
    var messageHandler: ((MessageStanza, ((Error?) -> Void)?) -> Void)?
    public func handleMessage(_ stanza: MessageStanza, completion: ((Error?) -> Void)? = nil) {
        messageHandler?(stanza, completion)
    }
    
    var IQHandler: ((IQStanza, TimeInterval, ((IQStanza?, Error?) -> Void)?) -> Void)?
    public func handleIQRequest(_ request: IQStanza,
                                timeout: TimeInterval,
                                completion: ((IQStanza?, Error?) -> Swift.Void)? = nil) {
        IQHandler?(request, timeout, completion)
    }
}
