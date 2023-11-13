//
//  Node.swift
//  LinkMapInspector
//
//  Created by StevenChoi on 2022/12/17.
//

import Cocoa

class Node: NSObject {
    @objc dynamic let name : String
    @objc dynamic var size : UInt64
    var allChildren : [Node] = []
    @objc dynamic var children : [Node]
    var filter : ((Node) -> Bool)? = nil {
        didSet {
            _updateChildren(self.filter)
        }
    }
    var object : Any?
    init(_ name : String, _ size : UInt64, _ children : [Node]) {
        self.name = name
        self.size = size
        self.allChildren = children
        self.children = children
    }
    
    @objc dynamic var isLeaf : Bool {
        return children.isEmpty
    }
    @objc dynamic var childCount: Int {
        return children.count
    }
    func _updateChildren(_ f : ((Node) -> Bool)? ) {
        self.allChildren.forEach { $0.filter = f }
        if let filter = f {
            self.children = allChildren.filter(filter)
        } else {
            self.children = self.allChildren
        }
    }
    func debugDescription() -> String {
        return "Node \(name) size\(size) \(childCount)  children"
    }
    @objc func compare(_ n: Node) -> ComparisonResult {
        return name.compare(n.name)
    }

    public static func convertToTreeNode(_ linkmap : LinkMap) ->  [String : [Node]] {
        var libMap = [String : [Node]]()
        var rootObjects = [UInt32:Node]()
        linkmap.objects.forEach {(obj : LinkMapObject) in
            var node = rootObjects[obj.index]
            if node == nil {
                node = Node(obj.name, 0, [])
                node!.object = obj
                rootObjects[obj.index] = node
            }
            let libName = obj.lib ?? linkmap.name
            var arr = libMap[libName] ?? []
            arr.append(node!)
            libMap[libName] = arr
        }
        linkmap.symbols.forEach { (symbol:SymbolObject) in
            let symNode = Node(symbol.name, symbol.size, [])
            rootObjects[symbol.objectIndex]!.children.append(symNode)
        }
        rootObjects.forEach { (idx, node) in
            node.size = node.children.reduce(0, { $0 + $1.size })
        }

        return libMap
    }
}
