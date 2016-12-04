//
//  SQLiteValues.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 01.12.16.
//  Copyright © 2016 Tobias Kraentzer. All rights reserved.
//

import Foundation
import SQLite
import CoreXMPP

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

extension MessageDirection: Value {
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    public static func fromDatatypeValue(_ datatypeValue: String) -> MessageDirection {
        return MessageDirection(rawValue: datatypeValue)!
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

extension QueryType {
    subscript(column: SQLite.Expression<UUID>) -> SQLite.Expression<UUID> {
        return namespace(column)
    }
    subscript(column: SQLite.Expression<JID>) -> SQLite.Expression<JID> {
        return namespace(column)
    }
    subscript(column: SQLite.Expression<MessageType>) -> SQLite.Expression<MessageType> {
        return namespace(column)
    }
    subscript(column: SQLite.Expression<MessageDirection>) -> SQLite.Expression<MessageDirection> {
        return namespace(column)
    }
    subscript(column: SQLite.Expression<NSError?>) -> SQLite.Expression<NSError?> {
        return namespace(column)
    }
}

extension String {
    func join(_ expressions: [Expressible]) -> Expressible {
        var (template, bindings) = ([String](), [Binding?]())
        for expressible in expressions {
            let expression = expressible.expression
            template.append(expression.template)
            bindings.append(contentsOf: expression.bindings)
        }
        return Expression<Void>(template.joined(separator: self), bindings)
    }
}

extension ExpressionType {
    public func alias(name: String) -> Expressible {
        return " ".join([self, Expression<Void>(literal: "AS \(name)")])
    }
}
