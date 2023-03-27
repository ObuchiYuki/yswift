//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

extension YDocument {
    public func applyUpdate(_ update: YUpdate, transactionOrigin: Any? = nil) throws {
        try _applyUpdate(to: self, update: update, transactionOrigin: transactionOrigin, YDecoder: YUpdateDecoderV1.init)
    }
    public func applyUpdateV2(_ update: YUpdate, transactionOrigin: Any? = nil) throws {
        try _applyUpdate(to: self, update: update, transactionOrigin: transactionOrigin, YDecoder: YUpdateDecoderV2.init)
    }
}

final class StructRef: CustomStringConvertible {
    var i: Int
    var refs: RefArray<YStruct?>
    
    init(i: Int, refs: RefArray<YStruct?>) { self.i = i; self.refs = refs }
    
    var description: String { "StructRef(i: \(i), refs: \(refs))" }
}

extension YUpdateDecoder {
    func readClientsStructRefs(doc: YDocument) throws -> RefDictionary<Int, StructRef> {
        
        let clientRefs = RefDictionary<Int, StructRef>()
        let numOfStateUpdates = try Int(self.restDecoder.readUInt())
        
        for _ in 0..<numOfStateUpdates {
            let numberOfStructs = try Int(self.restDecoder.readUInt())
            let refs = RefArray<YStruct?>(repeating: nil, count: numberOfStructs)
            let client = try self.readClient()
            var clock = try Int(self.restDecoder.readUInt())
            
            clientRefs.value[client] = StructRef(i: 0, refs: refs)
            
            for i in 0..<numberOfStructs {
                let info = try self.readInfo()
                let contentType = info & 0b0001_1111
                
                assert((0...10).contains(contentType))
                
                switch contentType {
                case 0:
                    let len = try self.readLen()
                    refs[i] = YGC(id: YID(client: client, clock: clock), length: len)
                    clock += len
                case 10:
                    let len = try Int(self.restDecoder.readUInt())
                    refs[i] = YSkip(id: YID(client: client, clock: clock), length: len)
                    clock += len
                    break
                default:
                    let cantCopyParentInfo = (info & (0b0100_0000 | 0b1000_0000)) == 0
                    let struct_ = try YItem(
                        id: YID(client: client, clock: clock),
                        left: nil,
                        origin: (info & 0b1000_0000) == 0b1000_0000 ? self.readLeftID() : nil, // origin
                        right: nil,
                        rightOrigin: (info & 0b0100_0000) == 0b0100_0000 ? self.readRightID() : nil, // right origin
                        parent: cantCopyParentInfo
                        ? (self.readParentInfo()
                           ? .object(doc.get(YObject.self, name: self.readString(), make: YObject.init))
                           : .id(self.readLeftID()))
                        : nil, // parent
                        parentSub: cantCopyParentInfo && (info & 0b0010_0000) == 0b0010_0000 ? self.readString() : nil, // parentSub
                        content: try decodeContent(from: self, info: info) // item content
                    )
                    refs[i] = struct_
                    clock += struct_.length
                }
            }
            
        }
        
        return clientRefs
    }
    
    public func readUpdate(ydoc: YDocument, transactionOrigin: Any?) throws {
        try ydoc.transact(origin: transactionOrigin, local: false) { transaction in
            transaction.local = false
            var retry = false
            let doc = transaction.doc
            
            let store = doc.store
            let uss = try self.readClientsStructRefs(doc: doc)
            
            let restStructs = try store.integrateStructs(transaction: transaction, clientsStructRefs: uss)
            
            let pending = store.pendingStructs
            if (pending != nil) {
                // check if we can apply something
                for (client, clock) in pending!.missing {
                    if clock < store.getState(client) {
                        retry = true
                        break
                    }
                }
                if (restStructs != nil) {
                    // merge restStructs into store.pending
                    for (client, clock) in restStructs!.missing {
                        let mclock = pending!.missing[client]
                        if mclock == nil || mclock! > clock {
                            pending!.missing[client] = clock
                        }
                    }
                    pending!.update = try YUpdate.mergedV2([pending!.update, restStructs!.update])
                }
            } else {
                store.pendingStructs = restStructs
            }
            
            let dsRest = try YDeleteSet.decodeAndApply(self, transaction: transaction, store: store)
            
            if store.pendingDs != nil {
                let pendingDSUpdate = try YUpdateDecoderV2(store.pendingDs!)
                _ = try pendingDSUpdate.restDecoder.readUInt() // read 0 structs, because we only encode deletes in pendingdsupdate
                let dsRest2 = try YDeleteSet.decodeAndApply(pendingDSUpdate, transaction: transaction, store: store)
                if dsRest != nil && dsRest2 != nil {
                    store.pendingDs = try YUpdate.mergedV2([dsRest!, dsRest2!])
                } else {
                    store.pendingDs = dsRest ?? dsRest2
                }
            } else {
                // Either dsRest == nil && pendingDs == nil OR dsRest != nil
                store.pendingDs = dsRest
            }
            
            if retry {
                let update = store.pendingStructs!.update
                store.pendingStructs = nil
                try _applyUpdate(to: transaction.doc, update: update, transactionOrigin: nil, YDecoder: YUpdateDecoderV2.init)
            }
        }
    }
}

fileprivate func _applyUpdate(to doc: YDocument, update: YUpdate, transactionOrigin: Any? = nil, YDecoder: (LZDecoder) throws -> YUpdateDecoder) throws {
    let decoder = LZDecoder(update.data)
    try YDecoder(decoder).readUpdate(ydoc: doc, transactionOrigin: transactionOrigin)
}
