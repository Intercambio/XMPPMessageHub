//
//  FileArchiveDocumentStore.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 27.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import PureXML

protocol ArchiveDocumentStore {
    func write(_ document: PXDocument, with uuid: UUID) throws -> Void
    func read(documentWith uuid: UUID) throws -> PXDocument
    func delete(documentWith uuid: UUID) throws
}

class FileArchiveFileDocumentStore: ArchiveDocumentStore {
    
    let directory: URL
    required init(directory: URL) {
        self.directory = directory
    }
    
    func write(_ document: PXDocument, with uuid: UUID) throws {
        let data = document.data()
        try data.write(to: path(with: uuid))
    }
    
    func read(documentWith uuid: UUID) throws -> PXDocument {
        let data = try Data(contentsOf: path(with: uuid))
        guard
            let document = PXDocument(data: data)
        else {
            throw ArchiveError.internalError
        }
        return document
    }
    
    func delete(documentWith uuid: UUID) throws {
        try FileManager.default.removeItem(at: path(with: uuid))
    }
    
    private func path(with uuid: UUID) -> URL {
        let name = "\(uuid.uuidString.lowercased()).xml"
        return directory.appendingPathComponent(name)
    }
}
