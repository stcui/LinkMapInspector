//
//  LinkMapDocument.swift
//  LinkMapViewer
//
//  Created by ShengCui on 2022/12/14.
//

import Foundation
import Combine

typealias LineProcesor = (String) -> LinkMapLineResult
public typealias ProgressHandler = (Int, Int) -> Void

enum LinkMapLineResult {
    case none
    case meta
    case mark(LineProcesor)
    case object(LinkMapObject)
    case section(SectionObject)
    case symbol(SymbolObject)
}

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

public enum LinkMapParserError : Error {
    case unknown
    case openFailed
    case parseFailed
    case canceled
}

public actor LinkMapParser {
    static let ProgressReportIntervalInBytes = 1024
    var currentFile : LinkMap? = nil
    var task : Task<(), Never>?
    
    public func cancel() {
        self.task?.cancel()
        self.currentFile = nil
    }
    
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
    
    private static func parseObjectLine(line: String) -> LinkMapObject? {
        let pattern = #"^\[[ \t]*(\d+)\][ \t]+(.*)$"#
        return  parseByRegex(line: line, pattern: pattern) { match in
            let idx  = line[Range(match.range(at: 1), in: line)!]
            let path = line[Range(match.range(at: 2), in: line)!]
            
            return LinkMapObject(hexToUInt32(idx), String(path))
        }
    }

    private static func parseSectionLine(line: String) -> SectionObject? {
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
    
    private static func parseSymbolLine(line: String) -> SymbolObject? {
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
    
    private func processLine(_ data : Data, lineProcessor:LineProcesor?) -> LinkMapLineResult {
        var line = String(data: data, encoding: .utf8)
        if line == nil {
            line = String(data: data, encoding: .ascii)
        }
        guard let line = line else {
            return .none;
        }
        
        let pathPrefix = "# Path: "
        let archPrefix = "# Arch: "
        let objectFilesPrefix = "# Object files:"
        let sectionPrefix = "# Sections:"
        let symbolsPrefix = "# Symbols:"
        
        if line.hasPrefix(pathPrefix) {
            let start = line.index(line.startIndex, offsetBy: pathPrefix.count)
            self.currentFile = LinkMap(path: String(line[start...]))
            return .meta
        } else if line.hasPrefix(archPrefix) {
            let start = line.index(line.startIndex, offsetBy: archPrefix.count)
            self.currentFile?.arch = String(line[start...])
            return .meta
        } else if line.hasPrefix(objectFilesPrefix) {
//            print("start objects")
            return .mark({ line in
                if let object = LinkMapParser.parseObjectLine(line: line) {
                    self.currentFile?.objects.append(object)
                    return .object(object)
                }
                return .none
            })
        } else if line.hasPrefix(sectionPrefix) {
//            print("start section")
            return .mark({ line in
                if let object = LinkMapParser.parseSectionLine(line: line) {
                    self.currentFile?.sections.append(object)
                    return .section(object)
                } else {
//                    print("error parse line: \(line)")
                }
                return .none
            })
        } else if line.hasPrefix(symbolsPrefix) {
            print("start symbols")
            return .mark { line in
                if let object = LinkMapParser.parseSymbolLine(line: line) {
                    self.currentFile?.symbols.append(object)
//                    print(line)
                    return .symbol(object)
                }
                return .none
            }
           
        } else if line.hasPrefix("#") {
            // skip
            return .none
        } else {
            return lineProcessor?(line) ?? .none
        }
    }
    
    public func parseData(data : Data, progressHandler: @escaping ProgressHandler ) async -> Result<LinkMap, LinkMapParserError> {
        var lineStart : Int = 0
        
        var lastUpdate = CFAbsoluteTimeGetCurrent()
        var lineProcessor : LineProcesor? = nil
        
        for i in 0..<data.count {
            if Task.isCancelled {
                return Result.failure(LinkMapParserError.canceled)
            }
            let ch = data[i]
            if ch == UInt8(ascii: "\n") {
                if (i > lineStart) {
                    autoreleasepool {
                        if case let .mark(processor) = self.processLine(data[lineStart..<i], lineProcessor: lineProcessor) {
                            lineProcessor = processor
                        }
                    }
                }
                lineStart = i+1
            }
            if i % Self.ProgressReportIntervalInBytes == 0 {
                let now = CFAbsoluteTimeGetCurrent()
                if now - lastUpdate > 0.3 {
                    lastUpdate = now
                    progressHandler(i, data.count)
                }
            }
        }
        if (lineStart < data.count) {
            _ = self.processLine(data[lineStart..<data.count], lineProcessor: lineProcessor)
        }
        progressHandler(data.count, data.count)
       
        if let file = self.currentFile {
            return Result.success(file)
        } else {
            return  Result.failure(LinkMapParserError.parseFailed)
        }
    }
    
    public func parseFile(path : String, progressHandler: @escaping ProgressHandler)async -> Result<LinkMap, LinkMapParserError> {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped) else {
            return Result.failure(LinkMapParserError.openFailed)
        }
        
        return await parseData(data: data, progressHandler: progressHandler)
    }
}
