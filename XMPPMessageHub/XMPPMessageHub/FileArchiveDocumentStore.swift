//
//  FileArchiveDocumentStore.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 27.11.16.
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
