//
//  Values.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 01.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import SQLite
import  CoreXMPP

extension UUID: Value {
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    public static func fromDatatypeValue(_ datatypeValue: String) -> UUID {
        return UUID(uuidString: datatypeValue)!
    }
    public var datatypeValue: String {
        return self.uuidString
    }
}

extension JID: Value {
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    public static func fromDatatypeValue(_ datatypeValue: String) -> JID {
        return JID(datatypeValue)!
    }
    public var datatypeValue: String {
        return self.stringValue
    }
}

extension MessageType: Value {
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    public static func fromDatatypeValue(_ datatypeValue: String) -> MessageType {
        return MessageType(rawValue: datatypeValue)!
    }
    public var datatypeValue: String {
        return self.rawValue
    }
}

extension NSError: Value {
    public static var declaredDatatype: String {
        return Blob.declaredDatatype
    }
    public static func fromDatatypeValue(_ datatypeValue: Blob) -> NSError {
        let data = Data(bytes: datatypeValue.bytes)
        return NSKeyedUnarchiver.unarchiveObject(with: data) as! NSError
    }
    public var datatypeValue: Blob {
        let data: Data = NSKeyedArchiver.archivedData(withRootObject: self)
        return data.withUnsafeBytes { bytes -> Blob in
            return Blob(bytes: bytes, length: data.count)
        }
    }
}
