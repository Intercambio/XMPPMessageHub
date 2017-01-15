//
//  MessageCarbonsHandler.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
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
            attributes: [.concurrent])
        super.init()
        dispatcher.add(self)
    }
    
    deinit {
        dispatcher.remove(self)
    }
    
    // MARK: - DispatcherHandler
    
    func didConnect(_ jid: JID, resumed: Bool, features: [Feature]?) {
        queue.async(flags: [.barrier]) {
            
            let shouldEnableMessageCarbons = true
            
            guard
                shouldEnableMessageCarbons == true,
                resumed == false
                else { return }
            
            let account = jid.bare()
            let request = self.makeRequest(for: account)
            let timeout = 120.0
            
            self.dispatcher.handleIQRequest(request, timeout: timeout, completion: { [weak self] (response, error) in
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
    
    func didDisconnect(_ JID: JID) { }
    
    private func makeRequest(for account: JID) -> IQStanza {
        let request = IQStanza.makeDocumentWithIQStanza(from: account, to: account)
        let iq = request.root as! IQStanza
        iq.type = .set
        iq.add(withName: "enable", namespace: "urn:xmpp:carbons:2", content: nil)
        
        return iq
    }
}
