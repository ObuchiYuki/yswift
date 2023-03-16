//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public protocol YText_or_YArray {
    var length: UInt { get }
}
//extension YText: YText_or_YArray {}
extension YArray: YText_or_YArray {}

public class ArraySearchMarker {
    public var timestamp: Int
    public var item: Item?
    public var index: UInt
    
    private static var globalSearchMarkerTimestamp = 0
    private static let maxSearchMarker = 80

    init(item: Item?, index: UInt) {
        self.item = item
        self.index = index
        if item != nil { item!.marker = true }
        self.timestamp = ArraySearchMarker.globalSearchMarkerTimestamp
        ArraySearchMarker.globalSearchMarkerTimestamp += 1
    }

    static public func markPosition(_ markers: inout [ArraySearchMarker], item: Item, index: UInt) -> ArraySearchMarker {
        if markers.count >= ArraySearchMarker.maxSearchMarker {
            // override oldest marker (we don't want to create more objects)
            let marker = markers.min(by: { $0.timestamp < $1.timestamp })!
            marker.overwrite(item, index: index)
            return marker
        } else {
            // create marker
            let pm = ArraySearchMarker(item: item, index: index)
            markers.append(pm)
            return pm
        }
    }
    
    /**
     * Search marker help us to find positions in the associative array faster.
     * They speed up the process of finding a position without much bookkeeping.
     * A maximum of `maxSearchMarker` objects are created.
     * This function always returns a refreshed marker (updated timestamp)
     */
    static public func find(_ yarray: AbstractType, index: UInt) -> ArraySearchMarker? {
        if yarray._start == nil || index == 0 || yarray._searchMarker == nil {
            return nil
        }
        
        let marker: ArraySearchMarker? = yarray._searchMarker!.count == 0
            ? nil
            : yarray._searchMarker!.jsReduce{ a, b in
                abs(Int(index) - Int(a.index)) < abs(Int(index) - Int(b.index)) ? a : b
            }
        
        var item: Item? = yarray._start
        var pindex: UInt = 0
        if marker != nil {
            item = marker!.item
            pindex = marker!.index
            marker!.refreshTimestamp() // we used it, we might need to use it again
        }
        // iterate to right if possible
        while (item?.right != nil && pindex < index) {
            if !item!.deleted && item!.countable {
                if index < pindex + item!.length {
                    break
                }
                pindex += item!.length
            }
            item = item!.right
        }
        // iterate to left if necessary (might be that pindex > index)
        while (item?.left != nil && pindex > index) {
            item = item!.left
            if !item!.deleted && item!.countable {
                pindex -= item!.length
            }
        }
        // we want to make sure that p can't be merged with left, because that would screw up everything
        // in that cas just return what we have (it is most likely the best marker anyway)
        // iterate to left until p can't be merged with left
        while (item?.left != nil && item!.left!.id.client == item!.id.client && item!.left!.id.clock + item!.left!.length == item!.id.clock) {
            item = item!.left
            if !item!.deleted && item!.countable {
                pindex -= item!.length
            }
        }

        if (item == nil) { return nil }
        
        let len = Int((item!.parent as! YText_or_YArray).length) / ArraySearchMarker.maxSearchMarker
        if marker != nil && abs(Int(marker!.index) - Int(pindex)) < len {
            // adjust existing marker
            marker!.overwrite(item!, index: pindex)
            return marker!
        } else {
            // create marker
            return ArraySearchMarker.markPosition(&yarray._searchMarker!, item: item!, index: pindex)
        }
    }

    static public func updateChanges(_ markers: inout [ArraySearchMarker], index: UInt, len: UInt) {
        for i in (0..<markers.count).reversed() {
            let marker = markers[i]
            
            if len > 0 {
                var item = marker.item
                if (item != nil) { item!.marker = false }
                // Ideally we just want to do a simple position comparison, but this will only work if
                // search markers don't point to deleted items for formats.
                // Iterate marker to prev undeleted countable position so we know what to do when updating a position
                while (item != nil && (item!.deleted || !item!.countable)) {
                    item = item!.left
                    if item != nil && !item!.deleted && item!.countable {
                        // adjust position. the loop should break now
                        marker.index -= item!.length
                    }
                }
                if item == nil || item!.marker == true {
                    // remove search marker if updated position is nil or if position is already marked
                    markers.remove(at: i)
                    continue
                }
                marker.item = item
                item!.marker = true
            }
            if index < marker.index || (len > 0 && index == marker.index) { // a simple index <= m.index check would actually suffice
                marker.index = max(index, marker.index + len)
            }
        }
    }


    public func refreshTimestamp() {
        self.timestamp = ArraySearchMarker.globalSearchMarkerTimestamp
        ArraySearchMarker.globalSearchMarkerTimestamp += 1
    }
        
    /** This is rather complex so this function is the only thing that should overwrite a marker */
    public func overwrite(_ item: Item, index: UInt) {
        if (self.item != nil) { self.item!.marker = false }
        self.item = item
        item.marker = true
        self.index = index
        self.timestamp = ArraySearchMarker.globalSearchMarkerTimestamp
        ArraySearchMarker.globalSearchMarkerTimestamp += 1
    }
}

