//
//  TestCase.swift
//  XMPPMessageHub
//
//  Created by Tobias Kraentzer on 20.11.16.
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


import XCTest
import Foundation

class TestCase: XCTestCase {
    
    var directory: URL?
    var dispatcher: TestDispatcher?
    
    override func setUp() {
        super.setUp()
        
        let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = temp.appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [:]
            )
            self.directory = directory
        } catch {
            XCTFail("Could not create temporary directory '\(directory)': \(error)")
        }
        
        dispatcher = TestDispatcher()
    }
    
    override func tearDown() {
        
        dispatcher = nil
        
        if let directory = self.directory {
            let fileManager = FileManager.default
            
            do {
                try fileManager.removeItem(at: directory)
                self.directory = nil
            } catch {
                XCTFail("Could not remove temporary directory '\(directory)': \(error)")
            }
        }
        
        super.tearDown()
    }
}
