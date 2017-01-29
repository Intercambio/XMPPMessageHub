//
//  TestDispatcher.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 09.01.17.
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

class TestDispatcher: Dispatcher {
    
    func send(_ message: MessageStanza, completion: ((Error?) -> Void)?) {
        let group = DispatchGroup()
        for handler in handlers.allObjects {
            if let messageHandler = handler as? MessageHandler {
                group.enter()
                messageHandler.handleMessage(message, completion: { _ in
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
    
    func add(_ handler: Handler, withIQQueryQNames _: [PXQName]?, features _: [Feature]?) {
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
    public func handleIQRequest(
        _ request: IQStanza,
        timeout: TimeInterval,
        completion: ((IQStanza?, Error?) -> Swift.Void)? = nil
    ) {
        IQHandler?(request, timeout, completion)
    }
}
