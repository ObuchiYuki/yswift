//
//  ID.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public class ID: Equatable {
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

    public static func decode(_ decoder: LZDecoder) throws -> ID {
        return ID(
            client: Int(try decoder.readUInt()),
            clock: Int(try decoder.readUInt())
        )
    }
    
    public static func == (lhs: ID, rhs: ID) -> Bool {
        return lhs.client == rhs.client && lhs.clock == rhs.clock
    }
}
