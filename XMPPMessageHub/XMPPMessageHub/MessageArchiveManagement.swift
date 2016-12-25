//
//  MessageArchiveManagement.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 21.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation

typealias MessageArchvieID = String

let MessageArchvieIDKey = "MessageArchvieIDKey"

struct MessageArchiveRequestResult {
    let first: MessageArchvieID
    let last: MessageArchvieID
    let stable: Bool
    let complete: Bool
    var messages: [MessageArchvieID:MessageID]
}

enum MessageArchiveRequestError: Error {
    case alreadyRunning
    case unexpectedResponse
    case internalError
}

protocol MessageArchiveRequestDelegate: class {
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFinishWith result: MessageArchiveRequestResult) -> Void
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFailWith error: Error) -> Void
}

protocol MessageArchiveRequestHandler {
    func savedMessage(with messageID: MessageID, userInfo: [AnyHashable:Any]) -> Void
    func failedSavingMessage(with error:Error, userInfo: [AnyHashable:Any]) -> Void
}

protocol MessageArchiveRequest {
    init(account: JID, timeout: TimeInterval)
    weak var iqHandler: IQHandler? { get set }
    weak var delegate: MessageArchiveRequestDelegate? { get set }
    func performFetch(before: MessageArchvieID?, limit: Int) throws -> (inboundFilter: MessageFilter, handler: MessageArchiveRequestHandler)
}
