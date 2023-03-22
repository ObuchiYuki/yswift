//
//  File.swift
//  
//
//  Created by yuki on 2023/03/22.
//

import Foundation
import yswift

struct YTestEnvironment {
    let encodeStateAsUpdate: (Doc, Data) throws -> Data
    let mergeUpdates: ([Data]) throws -> Data
    let applyUpdate: (Doc, Data, Any?) throws -> Void
    let logUpdate: (Data) -> Void
    let updateEventName: Doc.EventName<(update: Data, origin: Any?, Transaction)>
    let diffUpdate: (Data, Data) throws -> Data
        
    private static let v1 = YTestEnvironment(
        encodeStateAsUpdate: yswift.encodeStateAsUpdate,
        mergeUpdates: yswift.mergeUpdates,
        applyUpdate: yswift.applyUpdate,
        logUpdate: yswift.logUpdate,
        updateEventName: Doc.On.update,
        diffUpdate: yswift.diffUpdate
    )
    
    private static let v2 = YTestEnvironment(
        encodeStateAsUpdate: { try encodeStateAsUpdateV2(doc: $0, encodedTargetStateVector: $1) },
        mergeUpdates: { try mergeUpdatesV2(updates: $0) },
        applyUpdate: { try applyUpdateV2(ydoc: $0, update: $1, transactionOrigin: $2) },
        logUpdate: { logUpdateV2($0) },
        updateEventName: Doc.On.updateV2,
        diffUpdate: { try diffUpdateV2(update: $0, sv: $1) }
    )
    
    static var usingV2 = false
    static var currentEnvironment = YTestEnvironment.v1
    
    static func useV1() {
        self.usingV2 = false
        self.currentEnvironment = .v1
    }
    
    static func useV2() {
        // As syncProtocol dosen't support v2
        self.usingV2 = false
        self.currentEnvironment = .v1
    }
}
