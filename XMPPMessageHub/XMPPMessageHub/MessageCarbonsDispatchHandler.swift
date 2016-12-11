//
//  MessageCarbonsDispatchHandler.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation

protocol MessageCarbonsDispatchHandlerDelegate: class {
    func messageCarbonsDispatchHandler(_ handler: MessageCarbonsDispatchHandler, didEnableFor account: JID) -> Void
    func messageCarbonsDispatchHandler(_ handler: MessageCarbonsDispatchHandler, failedToEnableFor account: JID, wirth error: Error) -> Void
}

class MessageCarbonsDispatchHandler: NSObject, DispatcherHandler {
    
    weak var iqHandler: IQHandler?
    weak var delegate: MessageCarbonsDispatchHandlerDelegate?
    
    private let queue: DispatchQueue
    
    required override init() {
        queue = DispatchQueue(
            label: "MessageCarbonsDispatchHandler",
            attributes: [.concurrent])
        super.init()
    }
    
    // MARK: - DispatcherHandler
    
    func didConnect(_ jid: JID, resumed: Bool) {
        queue.async(flags: [.barrier]) {
            
            let shouldEnableMessageCarbons = true
            
            guard
                shouldEnableMessageCarbons == true,
                resumed == false,
                let handler = self.iqHandler
                else { return }
            
            let account = jid.bare()
            let request = self.makeRequest(for: account)
            let timeout = 120.0
            
            handler.handleIQRequest(request, timeout: timeout, completion: { [weak self] (response, error) in
                guard let this = self else { return }
                this.queue.async {
                    if let err = error {
                        this.delegate?.messageCarbonsDispatchHandler(this, failedToEnableFor: account, wirth: err)
                    } else {
                        this.delegate?.messageCarbonsDispatchHandler(this, didEnableFor: account)
                    }
                }
            })
        }
    }
    
    private func makeRequest(for account: JID) -> PXDocument {
        let request = IQStanza.makeDocumentWithIQStanza(from: account, to: account)
        let iq = request.root as! IQStanza
        iq.type = .set
        iq.add(withName: "enable", namespace: "urn:xmpp:carbons:2", content: nil)
        
        return request
    }
}
