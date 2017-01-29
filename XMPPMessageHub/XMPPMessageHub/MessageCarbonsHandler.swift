//
//  MessageCarbonsHandler.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.12.16.
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

protocol MessageCarbonsHandlerDelegate: class {
    func messageCarbonsHandler(_ handler: MessageCarbonsHandler, didEnableFor account: JID) -> Void
    func messageCarbonsHandler(_ handler: MessageCarbonsHandler, failedToEnableFor account: JID, wirth error: Error) -> Void
}

class MessageCarbonsHandler: NSObject, ConnectionHandler {
    
    weak var delegate: MessageCarbonsHandlerDelegate?
    
    private let queue: DispatchQueue
    private let dispatcher: Dispatcher
    
    init(dispatcher: Dispatcher) {
        self.dispatcher = dispatcher
        queue = DispatchQueue(
            label: "MessageCarbonsDispatchHandler",
            attributes: [.concurrent]
        )
        super.init()
        dispatcher.add(self)
    }
    
    deinit {
        dispatcher.remove(self)
    }
    
    // MARK: - DispatcherHandler
    
    func didConnect(_ jid: JID, resumed: Bool, features _: [Feature]?) {
        queue.async(flags: [.barrier]) {
            
            let shouldEnableMessageCarbons = true
            
            guard
                shouldEnableMessageCarbons == true,
                resumed == false
            else { return }
            
            let account = jid.bare()
            let request = self.makeRequest(for: account)
            let timeout = 120.0
            
            self.dispatcher.handleIQRequest(request, timeout: timeout, completion: { [weak self] _, error in
                guard let this = self else { return }
                this.queue.async {
                    if let err = error {
                        this.delegate?.messageCarbonsHandler(this, failedToEnableFor: account, wirth: err)
                    } else {
                        this.delegate?.messageCarbonsHandler(this, didEnableFor: account)
                    }
                }
            })
        }
    }
    
    func didDisconnect(_: JID) {}
    
    private func makeRequest(for account: JID) -> IQStanza {
        let iq = IQStanza(type: .set, from: account, to: account)
        iq.add(withName: "enable", namespace: "urn:xmpp:carbons:2", content: nil)
        return iq
    }
}
