//
//  SQLiteValues.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 01.12.16.
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
import SQLite
import XMPPFoundation

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
    fileprivate func x__join(_ expressions: [Expressible]) -> Expressible {
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
        return " ".x__join([self, Expression<Void>(literal: "AS \(name)")])
    }
}
