//
//  File.swift
//  
//
//  Created by yuki on 2023/03/20.
//

import Foundation
@testable import yswift

final public class UpdateEnvironment {
    let mergeUpdates: (_ updates: [Data]) throws -> Data
    let encodeStateAsUpdate: (_ doc: Doc, _ encodedTargetStateVector: Data?) throws -> Data
    let applyUpdate: (_ ydoc: Doc, _ update: Data, _ transactionOrigin: Any?) throws -> Void
    let logUpdate: (_ update: Data) -> Void
    let parseUpdateMeta: (_ update: Data) throws -> UpdateMeta
    let encodeStateVectorFromUpdate: (_ update: Data) throws -> Data
    let encodeStateVector_Doc: (_ doc: Doc) throws -> Data
    let encodeStateVector_SV: (_ doc: [Int: Int]) throws -> Data
    let updateEventName: Doc.EventName<(update: Data, origin: Any?, Transaction)>
    let description: String
    let diffUpdate: (_ update: Data, _ sv: Data) throws -> Data
    
    init(
        mergeUpdates: @escaping ([Data]) throws -> Data,
        encodeStateAsUpdate: @escaping (Doc, Data?) throws -> Data,
        applyUpdate: @escaping (Doc, Data, Any?) throws -> Void,
        logUpdate: @escaping (Data) -> Void,
        parseUpdateMeta: @escaping (Data) throws -> UpdateMeta,
        encodeStateVectorFromUpdate: @escaping (Data) throws -> Data,
        encodeStateVector_Doc: @escaping (Doc) throws -> Data,
        encodeStateVector_SV: @escaping ([Int : Int]) throws -> Data,
        updateEventName: Lib0Observable.EventName<(update: Data, origin: Any?, Transaction)>,
        description: String,
        diffUpdate: @escaping (Data, Data) throws -> Data
    ) {
        self.mergeUpdates = mergeUpdates
        self.encodeStateAsUpdate = encodeStateAsUpdate
        self.applyUpdate = applyUpdate
        self.logUpdate = logUpdate
        self.parseUpdateMeta = parseUpdateMeta
        self.encodeStateVectorFromUpdate = encodeStateVectorFromUpdate
        self.encodeStateVector_Doc = encodeStateVector_Doc
        self.encodeStateVector_SV = encodeStateVector_SV
        self.updateEventName = updateEventName
        self.description = description
        self.diffUpdate = diffUpdate
    }

    
    static let v1 = UpdateEnvironment(
        mergeUpdates: { try yswift.mergeUpdates(updates: $0) },
        encodeStateAsUpdate: { try yswift.encodeStateAsUpdate(doc: $0, encodedTargetStateVector: $1) },
        applyUpdate: { try yswift.applyUpdate(ydoc: $0, update: $1, transactionOrigin: $2) },
        logUpdate: { yswift.logUpdate($0) },
        parseUpdateMeta: { try yswift.parseUpdateMeta(update: $0) },
        encodeStateVectorFromUpdate: { try yswift.encodeStateVectorFromUpdate(update: $0) },
        encodeStateVector_Doc: { try encodeStateVector(doc: $0) },
        encodeStateVector_SV: { try encodeStateVector(doc: $0) },
        updateEventName: Doc.On.update,
        description: "V1",
        diffUpdate: { try yswift.diffUpdate(update: $0, sv: $1) }
    )

    static let v2 = UpdateEnvironment(
        mergeUpdates: { try mergeUpdatesV2(updates: $0) },
        encodeStateAsUpdate: { try encodeStateAsUpdateV2(doc: $0, encodedTargetStateVector: $1) },
        applyUpdate: { try applyUpdateV2(ydoc: $0, update: $1, transactionOrigin: $2) },
        logUpdate: { logUpdateV2($0) },
        parseUpdateMeta: { try parseUpdateMetaV2(update: $0) },
        encodeStateVectorFromUpdate: { try encodeStateVectorFromUpdateV2(update: $0) },
        encodeStateVector_Doc: { try encodeStateVector(doc: $0) },
        encodeStateVector_SV: { try encodeStateVector(doc: $0) },
        updateEventName: Doc.On.updateV2,
        description: "V2",
        diffUpdate: { try diffUpdateV2(update: $0, sv: $1) }
    )

    static let doc = UpdateEnvironment(
        mergeUpdates: { updates in
            let ydoc = Doc(opts: DocOpts(gc: false))
            try updates.forEach({ update in
                try applyUpdateV2(ydoc: ydoc, update: update)
            })
            return try encodeStateAsUpdateV2(doc: ydoc)
        },
        encodeStateAsUpdate: { try encodeStateAsUpdateV2(doc: $0, encodedTargetStateVector: $1) },
        applyUpdate: { try applyUpdateV2(ydoc: $0, update: $1, transactionOrigin: $2) },
        logUpdate: { logUpdateV2($0) },
        parseUpdateMeta: { try parseUpdateMetaV2(update: $0) },
        encodeStateVectorFromUpdate: { try encodeStateVectorFromUpdateV2(update: $0) },
        encodeStateVector_Doc: { try encodeStateVector(doc: $0) },
        encodeStateVector_SV: { try encodeStateVector(doc: $0) },
        updateEventName: Doc.On.updateV2,
        description: "Merge via Doc",
        diffUpdate: { update, sv in
            let ydoc = Doc(opts: DocOpts(gc: false))
            try applyUpdateV2(ydoc: ydoc, update: update)
            return try encodeStateAsUpdateV2(doc: ydoc, encodedTargetStateVector: sv)
        }
    )

    static let encoders = [UpdateEnvironment.v1, .v2, .doc]
    
    func docFromUpdates(_ docs: [Doc]) throws -> Doc {
        let updates = try docs.map{
            try self.encodeStateAsUpdate($0, nil)
        }
                
        let ydoc = Doc()
        try self.applyUpdate(ydoc, self.mergeUpdates(updates), nil)
        return ydoc
    }
}
