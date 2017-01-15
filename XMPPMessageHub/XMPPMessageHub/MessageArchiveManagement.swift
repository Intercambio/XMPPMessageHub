//
//  MessageArchiveManagement.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 21.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import XMPPFoundation

typealias MessageArchiveID = String

enum MessageArchiveRequestError: Error {
    case alreadyRunning
    case unexpectedResponse
    case internalError
}

protocol MessageArchiveRequestDelegate: class {
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFinishWith response: MAMIndexPartition) -> Void
    func messageArchiveRequest(_ request: MessageArchiveRequest, didFailWith error: Error) -> Void
}

protocol MessageArchiveRequest {
    init(dispatcher: Dispatcher, archive: Archive)
    weak var delegate: MessageArchiveRequestDelegate? { get set }
    var queryID: String { get }
    func performFetch(before: MessageArchiveID?, limit: Int, timeout: TimeInterval) throws -> Void
}

protocol MessageArchiveManagement {
    func loadRecentMessages(for account: JID, completion:((Error?)->Void)?) -> Void
    func canLoadMoreMessages(for account: JID) -> Bool
    func loadMoreMessages(for account: JID, completion:((Error?)->Void)?) -> Void
}
