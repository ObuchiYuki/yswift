//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

extension Doc {
    public func encodeStateVector() throws -> Data {
        try DSEncoderV1().encodeStateVector(from: self)
    }
    public func encodeStateVectorV2() throws -> Data {
        try DSEncoderV2().encodeStateVector(from: self)
    }
}

extension DSEncoder {
    
    public func writeStateVector(from stateVector: [Int: Int]) throws {
        self.restEncoder.writeUInt(UInt(stateVector.count))
        
        for (client, clock) in stateVector.sorted(by: { $0.key > $1.key }) {
            self.restEncoder.writeUInt(UInt(client))
            self.restEncoder.writeUInt(UInt(clock))
        }
    }
    public func writeStateVector(from doc: Doc) throws {
        try self.writeStateVector(from: doc.store.getStateVector())
    }

    public func encodeStateVector(from stateVector: [Int: Int]) throws -> Data {
        try self.writeStateVector(from: stateVector)
        return self.toData()
    }

    public func encodeStateVector(from doc: Doc) throws -> Data {
        try self.writeStateVector(from: doc)
        return self.toData()
    }

}

