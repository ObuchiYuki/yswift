//
//  YID.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public class YID: Equatable {
    /// Client id
    public var client: Int
    /// unique per client id, continuous Int */
    public var clock: Int

    public init(client: Int, clock: Int) {
        self.client = client
        self.clock = clock
    }

    public func encode(_ encoder: LZEncoder) {
        encoder.writeUInt(UInt(self.client))
        encoder.writeUInt(UInt(self.clock))
    }

    public static func decode(_ decoder: LZDecoder) throws -> YID {
        return YID(
            client: Int(try decoder.readUInt()),
            clock: Int(try decoder.readUInt())
        )
    }
    
    public static func == (lhs: YID, rhs: YID) -> Bool {
        return lhs.client == rhs.client && lhs.clock == rhs.clock
    }
}
