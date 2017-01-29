//
//  KeyedArchiving.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.01.17.
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

protocol Dictionariable {
    func dictionaryRepresentation() -> NSDictionary
    init?(dictionaryRepresentation: NSDictionary?)
}

extension NSKeyedUnarchiver {
    class func unarchiveStructure<T: Dictionariable>(with data: Data) -> T? {
        guard
            let encodedDict = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSDictionary
        else { return nil }
        return T(dictionaryRepresentation: encodedDict)
    }
    class func unarchiveStructure<T: Dictionariable>(withFile path: String) -> T? {
        guard
            let encodedDict = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? NSDictionary
        else { return nil }
        return T(dictionaryRepresentation: encodedDict)
    }
}

extension NSKeyedArchiver {
    class func archivedData<T: Dictionariable>(withStructure structure: T) -> Data {
        let encodedValue = structure.dictionaryRepresentation()
        return NSKeyedArchiver.archivedData(withRootObject: encodedValue)
    }
    class func archiveStructure<T: Dictionariable>(structure: T, toFile path: String) {
        let encodedValue = structure.dictionaryRepresentation()
        NSKeyedArchiver.archiveRootObject(encodedValue, toFile: path)
    }
}
