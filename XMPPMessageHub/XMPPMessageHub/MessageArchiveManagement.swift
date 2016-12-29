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

struct MessageArchiveRequestResult {
    let first: MessageArchvieID
    let last: MessageArchvieID
    let stable: Bool
    let complete: Bool
    let messages: [MessageArchvieID:MessageID]
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

protocol MessageArchiveRequest {
    init(dispatcher: Dispatcher, archive: Archive)
    weak var delegate: MessageArchiveRequestDelegate? { get set }
    func performFetch(before: MessageArchvieID?, limit: Int, timeout: TimeInterval) throws -> Void
}

protocol MessageArchiveManagement {
}
