//
//  LinkMapDocument.swift
//  LinkMapViewer
//
//  Created by ShengCui on 2022/12/14.
//

import Foundation

public class LinkMapObject {
    init(_ index : UInt32, _ path: String) {
        self.index = index
        self.path = path
        let filename = (path as NSString).lastPathComponent
        if filename.hasSuffix(")") {
            let components = filename.components(separatedBy: "(")
            self.lib = components.first
            let frameworkSuffix = ".framework"

            if let frameworkIdx = path.range(of: frameworkSuffix,
                                             options: .backwards,
                                             range: nil ),
               let separatorIdx = path[path.startIndex..<frameworkIdx.lowerBound].lastIndex(of: "/") {
                    let frameworkName = path[path.index(after: separatorIdx)..<frameworkIdx.upperBound]
                    self.lib = String(frameworkName)
            }
            var last = components.last!
            last.remove(at: last.index(before: last.endIndex))
            self.name = last
        } else {
            self.name = filename
        }
    }
    public var index: UInt32
    public var path: String
    public var lib: String?
    public var name: String
}

public struct SectionObject {
    public var address: UInt64
    public var size   : UInt64
    public var segment: String
    public var section: String
}

public struct SymbolObject {
    public var address: UInt64
    public var size   : UInt64
    public var objectIndex : UInt32
    public var name : String
    public var dead : Bool
}

public struct LinkMap {
    init(path : String) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
    }
    public var arch : String = ""
    public let path : String
    public let name : String
    public var objects : [LinkMapObject] = []
    public var sections : [SectionObject] = []
    public var symbols : [SymbolObject] = []
}

public class LinkMapParser {
    public var linkmaps : [LinkMap] = []
    var currentFile : LinkMap? = nil
    var lineProcessor : ((String) -> Void)? = nil
    
    
    static func hexToUInt32(_ hex: Substring) -> UInt32 {
        let literal = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : String(hex)
        return UInt32(literal, radix: 16) ?? 0
    }
    static func hexToUInt64(_ hex: Substring) -> UInt64 {
        let literal = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : String(hex)
        return UInt64(literal, radix: 16) ?? 0
    }

    static func parseByRegex<T>(line: String,
                                pattern: String,
                                _ mapper: (NSTextCheckingResult) -> T) -> T? {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: line.lengthOfBytes(using: .ascii)))
            if let match = matches.first {
                return mapper(match)
            }
        } catch let error {
            print("error: \(error)")
            return nil
        }
        return nil
    }
    
    public static func parseObjectLine(line: String) -> LinkMapObject? {
        let pattern = #"^\[[ \t]*(\d+)\][ \t]+(.*)$"#
        return parseByRegex(line: line, pattern: pattern) { match in
            let idx  = line[Range(match.range(at: 1), in: line)!]
            let path = line[Range(match.range(at: 2), in: line)!]
            
            return LinkMapObject(hexToUInt32(idx), String(path))
        }
    }

    public static func parseSectionLine(line: String) -> SectionObject? {
        let pattern = #"^(0x[0-9A-F]+)[ \t]+(0x[0-9A-F]+)[ \t]+([^ \t]+)[ \t]+([^ \t]+)$"#
        return parseByRegex(line: line, pattern: pattern) { match in
            let addr    = line[Range(match.range(at: 1), in: line)!]
            let size    = line[Range(match.range(at: 2), in: line)!]
            let segment = line[Range(match.range(at: 3), in: line)!]
            let section = line[Range(match.range(at: 4), in: line)!]
            return SectionObject(address: hexToUInt64(addr),
                                 size: hexToUInt64(size),
                                 segment: String(segment),
                                 section: String(section))
        }
    }
    
    public static func parseSymbolLine(line: String) -> SymbolObject? {
        let pattern = #"^(0x[0-9A-F]+)+[ \t]+(0x[0-9A-F]+)+[ \t]+\[[ \t+]*(\d+)\][ \t]+(.*)$"#
        return parseByRegex(line: line, pattern: pattern) { match in
            let addr = line[Range(match.range(at: 1), in: line)!]
            let size = line[Range(match.range(at: 2), in: line)!]
            let idx  = line[Range(match.range(at: 3), in: line)!]
            let name = line[Range(match.range(at: 4), in: line)!]
//            print("addr: \(addr) size:\(size) idx:\(idx)")
            return SymbolObject(address: hexToUInt64(addr),
                                size: hexToUInt64(size),
                                objectIndex: hexToUInt32(idx),
                                name: String(name),
                                dead: addr == "<<dead>>")
        }
    }
    
    public init() {
    }
    
    private func processLine(_ data : Data) {
        guard let line = String(data: data, encoding: .utf8) else {
            return;
        }
        
        let pathPrefix = "# Path: "
        let archPrefix = "# Arch: "
        let objectFilesPrefix = "# Object files:"
        let sectionPrefix = "# Sections:"
        let symbolsPrefix = "# Symbols:"
        
        if line.hasPrefix(pathPrefix) {
            if let file = currentFile {
                linkmaps.append(file)
            }
            let start = line.index(line.startIndex, offsetBy: pathPrefix.count)
            self.currentFile = LinkMap(path: String(line[start...]))
        } else if line.hasPrefix(archPrefix) {
            let start = line.index(line.startIndex, offsetBy: archPrefix.count)
            self.currentFile?.arch = String(line[start...])
        } else if line.hasPrefix(objectFilesPrefix) {
//            print("start objects")
            self.lineProcessor = { line in
                if let object = LinkMapParser.parseObjectLine(line: line) {
                    self.currentFile?.objects.append(object)
                }
            }
        } else if line.hasPrefix(sectionPrefix) {
//            print("start section")
            self.lineProcessor = { line in
                if let object = LinkMapParser.parseSectionLine(line: line) {
                    self.currentFile?.sections.append(object)
                } else {
//                    print("error parse line: \(line)")
                }
            }
        } else if line.hasPrefix(symbolsPrefix) {
            print("start symbols")
            self.lineProcessor = { line in
                if let object = LinkMapParser.parseSymbolLine(line: line) {
                    self.currentFile?.symbols.append(object)
//                    print(line)
                }
            }
        } else if line.hasPrefix("#") {
            // skip
        } else {
            self.lineProcessor?(line)
        }
    }
    
    public func parseData(data : Data) {
        var lineStart : Int = 0
        for i in 0..<data.count {
            let ch = data[i]
            if ch == UInt8(ascii: "\n") {
                if (i > lineStart) {
                    processLine(data[lineStart..<i])
                }
                lineStart = i+1
            }
        }
        if (lineStart < data.count) {
            processLine(data[lineStart..<data.count])
        }
        if let file = currentFile {
            linkmaps.append(file)
        }
    }
    
    public func parseFile(path : String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped) else {
            return
        }
        parseData(data: data)
    }
}
