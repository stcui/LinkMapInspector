//
//  NodeTests.swift
//  LinkMapInspectorTests
//
//  Created by StevenChoi on 2022/12/17.
//

import XCTest

@testable import LinkMapInspector

final class NodeTests: XCTestCase {
    
    func testNode() throws {
        let path = Bundle(for: self.classForCoder).path(forResource: "LinkMapViewer-LinkMap-normal-x86_64", ofType: "txt")
        XCTAssertNotNil(path, "resource missing")
        let parser = LinkMapParser()
        parser.parseFile(path: path!)
        XCTAssertGreaterThan(parser.linkmaps.count, 0)
        let linkmap = parser.linkmaps.first!
        XCTAssertEqual(linkmap.objects.count, 11)
        XCTAssertEqual(linkmap.sections.count, 28)
        XCTAssertEqual(linkmap.symbols.count, 1127)
        
        let libMap = Node.convertToTreeNode(linkmap)
        XCTAssertEqual(libMap.count, 2)
        XCTAssertNotNil(libMap["Exe"])
        XCTAssertNotNil(libMap["ff"])
        XCTAssertEqual(libMap["Exe"]?.count, 10)

    }
}
