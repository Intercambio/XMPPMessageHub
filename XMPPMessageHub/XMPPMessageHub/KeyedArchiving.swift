//
//  KeyedArchiving.swift
//  XMPPMessageHub
//
//  Created by Tobias Kräntzer on 08.01.17.
//  Copyright © 2017 Tobias Kraentzer. All rights reserved.
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
            else {return nil}
        return T(dictionaryRepresentation: encodedDict)
    }
    class func unarchiveStructure<T: Dictionariable>(withFile path: String) -> T? {
        guard
            let encodedDict = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? NSDictionary
            else {return nil}
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
