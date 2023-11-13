//
//  ViewController.swift
//  LinkMapInspector
//
//  Created by StevenChoi on 2022/12/16.
//

import Cocoa
import Dispatch
import Combine

let kSuggestionLabel = "label"

class ViewController: NSViewController, NSSearchFieldDelegate {

    @IBOutlet weak var textField: NSTextField!
    @IBOutlet var treeController : NSTreeController!
    @objc dynamic var nodes : [Node] = []
    @IBOutlet weak var searchBar: NSSearchField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    var observer : [AnyCancellable] = []
    var keywords:[String] = []

    
    var sizeDataFormate =  NumberFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sizeDataFormate.numberStyle = .decimal
        updateByDocument()
    }
    
    func updateByDocument() {
        observer.forEach{$0.cancel()}
        observer.removeAll()
        
        guard let object = self.representedObject as? Document else {
            self.nodes = []
            return
        }
        self.textField.stringValue = "Loading..."
        self.observer.append(object.$linkmap
            .sink { [weak self] linkmap in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if linkmap != nil {
                        self.updateByObject(linkmap!)
                    }
                }
            })
        self.observer.append(object.$state.sink { [weak self] state in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch state {
                case .idle:
                    self.textField.stringValue = "Not loaded"
                case .loading:
                    self.textField.stringValue = "Loading"
                case .loaded:
                    self.progressIndicator.isHidden = true
                    break;
                }
            }
        })
    }
    
    func updateByObject(_ linkMap : LinkMap) {
        let libMap = Node.convertToTreeNode(linkMap)

        keywords = linkMap.objects.compactMap { $0.name }

        var displayNodes = [Node]()
        libMap.forEach { (lib, nodes) in
            let n = Node(lib, nodes.reduce(0){$0+$1.size}, nodes)
            displayNodes.append(n)
        }
        self.nodes = displayNodes;
        debugPrint("updating linkmap \(nodes.count) nodes, sortedObjects: \(treeController.arrangedObjects)")
        
        
        self.textField.stringValue = """
        \(linkMap.objects.count) objects \(linkMap.sections.count) sections \(linkMap.symbols.count) symbols \(nodes.count) libs
        """
        self.treeController.rearrangeObjects()
    }
    
    override var representedObject: Any? {
        didSet {
            updateByDocument()
        }
    }
    
    private func findNodes(keyword:String, idxPrefix:[Int],nodes:[Node])->[IndexPath] {
        var result = [IndexPath]()

        for i in (0..<nodes.count) {
            let node = nodes[i]
            var path = idxPrefix
            path.append(i)

            debugPrint("trying \(node.name) \(node.name.lowercased())")
            if (node.name.lowercased().contains(keyword)) {
                debugPrint("\(node.name.lowercased()) matched")

                let idxPath = IndexPath(indexes: path)
                result.append(idxPath)
            }
            result.append(contentsOf: findNodes(keyword:keyword, idxPrefix:path, nodes: node.children))

        }
        return result
    }
    
    func controlTextDidChange(_ obj: Notification) {
        let keyword = searchBar.stringValue.lowercased()
        if (keyword.isEmpty) {
            self.nodes.forEach{ $0.filter = nil }
        } else {
            self.nodes.forEach{ $0.filter = { $0.name.lowercased().contains(keyword) } }
        }
        let nodes = self.nodes
        self.nodes = nodes
    }
}
