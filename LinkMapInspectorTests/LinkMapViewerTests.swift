//
//  LinkMapViewerTests.swift
//  LinkMapViewerTests
//
//  Created by ShengCui on 2022/12/14.
//

import XCTest
import LinkMapInspector

final class LinkMapViewerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testParseObjectLine() throws {
        let line = "[  1] /Users/stcui/Library/Developer/Xcode/DerivedData/LinkMapViewer-gnshatiyysuzizaemykvvsoxmhee/Build/Intermediates.noindex/LinkMapViewer.build/Debug/LinkMapViewer.build/Objects-normal/x86_64/LinkMap.o"
        let result = LinkMapParser.parseObjectLine(line: line)
        XCTAssertNotNil(result)
        if let r = result {
            XCTAssertEqual(r.index, 1)
            XCTAssertEqual(r.path, "/Users/stcui/Library/Developer/Xcode/DerivedData/LinkMapViewer-gnshatiyysuzizaemykvvsoxmhee/Build/Intermediates.noindex/LinkMapViewer.build/Debug/LinkMapViewer.build/Objects-normal/x86_64/LinkMap.o")
            XCTAssertEqual(r.name, "LinkMap.o")
            XCTAssertNil(r.lib)
        }
    }
    func testParseObjectLine1() throws {
        let line = "[  4] /Users/stcui/Library/Developer/Xcode/DerivedData/LinkMapViewer-gnshatiyysuzizaemykvvsoxmhee/Build/Products/Debug/ff.framework/ff(ff.o)"
        let result = LinkMapParser.parseObjectLine(line: line)
        XCTAssertNotNil(result)
        if let r = result {
            XCTAssertEqual(r.index, 4)
            XCTAssertEqual(r.path, "/Users/stcui/Library/Developer/Xcode/DerivedData/LinkMapViewer-gnshatiyysuzizaemykvvsoxmhee/Build/Products/Debug/ff.framework/ff(ff.o)")
            XCTAssertEqual(r.name, "ff.o")
            XCTAssertEqual(r.lib, "ff.framework")
        }
    }
    func testParseSymbol() throws {
        let line = "0x100004000    0x0000006C    [  1] -[UIView(MASConstraints) mas_installedConstraints]"
        let result = LinkMapParser.parseSymbolLine(line: line)
        XCTAssertNotNil(result)
        if let r = result {
            XCTAssertEqual(r.address, 0x100004000)
            XCTAssertEqual(r.size, 0x0000006C)
            XCTAssertEqual(r.objectIndex, 1)
            XCTAssertEqual(r.name, "-[UIView(MASConstraints) mas_installedConstraints]")
        }
    }
    func testParseSection() throws {
        let line = "0x10000F0AA    0x000001B0    __TEXT    __swift5_typeref"
        let result = LinkMapParser.parseSectionLine(line: line)
        XCTAssertNotNil(result)
        if let r = result {
            XCTAssertEqual(r.address, 0x10000F0AA)
            XCTAssertEqual(r.size, 0x000001B0)
            XCTAssertEqual(r.segment, "__TEXT")
            XCTAssertEqual(r.section, "__swift5_typeref")
        }
    }
    
    func testParseFile() throws {
        let path = Bundle(for: self.classForCoder).path(forResource: "LinkMapViewer-LinkMap-normal-x86_64", ofType: "txt")
        XCTAssertNotNil(path, "resource missing")
        let parser = LinkMapParser()
        parser.parseFile(path: path!)
        XCTAssertGreaterThan(parser.linkmaps.count, 0)
        let linkmap = parser.linkmaps.first!
        XCTAssertEqual(linkmap.objects.count, 11)
        XCTAssertEqual(linkmap.sections.count, 28)
        XCTAssertEqual(linkmap.symbols.count, 1127)

    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            let path = Bundle(for: self.classForCoder).path(forResource: "LinkMapViewer-LinkMap-normal-x86_64", ofType: "txt")
            let parser = LinkMapParser()
            parser.parseFile(path: path!)
        }
    }

}
