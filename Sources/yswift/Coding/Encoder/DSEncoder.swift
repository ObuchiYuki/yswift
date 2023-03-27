//
//  File.swift
//  
//
//  Created by yuki on 2023/03/25.
//

import Foundation

public protocol DSEncoder {
    var restEncoder: LZEncoder { get set }
    var updateVersion: YUpdate.Version { get }
    
    func resetDeleteSetValue()
    func writeDeleteSetClock(_ clock: Int)
    func writeDeleteSetLen(_ len: Int) throws
    func toData() -> Data
}

extension DSEncoder {
    func toUpdate() -> YUpdate { YUpdate(toData(), version: self.updateVersion) }
}

public class DSEncoderV1: DSEncoder {
    public var restEncoder = LZEncoder()
    
    public var updateVersion: YUpdate.Version { .v1 }

    public init() {}

    public func toData() -> Data {
        return self.restEncoder.data
    }

    public func resetDeleteSetValue() {}

    public func writeDeleteSetClock(_ clock: Int) {
        self.restEncoder.writeUInt(UInt(clock))
    }

    public func writeDeleteSetLen(_ len: Int) {
        self.restEncoder.writeUInt(UInt(len))
    }
}

public class DSEncoderV2: DSEncoder {
    public var restEncoder = LZEncoder()
    
    public var updateVersion: YUpdate.Version { .v2 }
    
    private var dsCurrVal = 0

    public init() {}

    public func toData() -> Data {
        return self.restEncoder.data
    }

    public func resetDeleteSetValue() {
        self.dsCurrVal = 0
    }

    public func writeDeleteSetClock(_ clock: Int) {
        let diff = clock - self.dsCurrVal
        self.dsCurrVal = clock
        self.restEncoder.writeUInt(UInt(diff))
    }

    public func writeDeleteSetLen(_ len: Int) throws {
        if len == 0 {
            throw YSwiftError.unexpectedCase
        }
        self.restEncoder.writeUInt(UInt(len - 1))
        self.dsCurrVal += len
    }
}
