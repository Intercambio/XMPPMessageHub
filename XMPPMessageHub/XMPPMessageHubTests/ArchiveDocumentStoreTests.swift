//
//  ArchiveDocumentStoreTests.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 27.11.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import XCTest
import PureXML
@testable import XMPPMessageHub

class ArchiveDocumentStoreTests: TestCase {
    
    func test() {
        guard let directory = self.directory else { return }
        guard let document = PXDocument(elementName: "message", namespace: "jabber:client", prefix: nil) else { return }
        document.root.setValue("123", forAttribute: "id")
        
        do {
            let uuid = UUID()
            let store = FileArchiveFileDocumentStore(directory: directory)
            
            try store.write(document, with: uuid)
            
            let document = try store.read(documentWith: uuid)
            XCTAssertEqual(document.root.value(forAttribute: "id") as? String, "123")
            
            try store.delete(documentWith: uuid)
            XCTAssertThrowsError(try store.read(documentWith: uuid))
            
        } catch {
            XCTFail("\(error)")
        }
    }
}
