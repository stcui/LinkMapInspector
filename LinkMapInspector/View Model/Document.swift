//
//  Document.swift
//  LinkMapInspector
//
//  Created by StevenChoi on 2022/12/16.
//

import Cocoa
import Combine
import UniformTypeIdentifiers

class Document: NSDocument {
    public enum State {
        case idle
        case loading
        case loaded
    }
    
    let parser = LinkMapParser()
    @Published var linkmap : LinkMap? = nil
    @Published var state: State = .idle
    @objc var progress : Progress = Progress()
    var errorString: String? = nil
    var loadTask :Task<(), Never>? = nil
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }
    override func close()  {
        NSDocumentController.shared.removeDocument(self)
        self.linkmap = nil;
        self.loadTask?.cancel()
        Task {
            await self.parser.cancel()
        }
//        self.windowControllers.first?.contentViewController
    }
    override class var autosavesInPlace: Bool {
        return false
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        windowController.contentViewController?.representedObject = self
        self.addWindowController(windowController)
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type, throwing an error in case of failure.
        // Alternatively, you could remove this method and override fileWrapper(ofType:), write(to:ofType:), or write(to:ofType:for:originalContentsURL:) instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        self.loadTask?.cancel()
        if !(UTType(typeName)?.conforms(to: UTType.text) ?? false) {
            self.state = .idle
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        self.state = .loading
        let task = Task {
            let parseResult = await parser.parseData(data: data) { (current, total) in
                DispatchQueue.main.async {
                    self.progress.completedUnitCount = Int64(current)
                    self.progress.totalUnitCount = Int64(total)
                }
                
            }
            DispatchQueue.main.async {
                switch parseResult {
                case let .success(linkmap):
                    self.linkmap = linkmap
                    self.state = .loaded
                case let .failure(error):
                    switch error {
                    case .unknown:
                        self.errorString = "Unknown"
                    case .openFailed:
                        self.errorString = "OpenFailed"
                    case .parseFailed:
                        self.errorString = "ParseFailed"
                    case .canceled:
                        self.errorString = "Canceled"
                    }
                    self.state = .idle
                }
            }
            
        }
        self.loadTask = task
        //self.progress = await parser.progress?.progress
    }
}

