//
//  ID.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import lib0

public class ID: Equatable {
    /// Client id
    public var client: UInt
    /// unique per client id, continuous Int */
    public var clock: UInt

    public init(client: UInt, clock: UInt) {
        self.client = client
        self.clock = clock
    }

    public func encode(_ encoder: Lib0Encoder) {
        encoder.writeUInt(self.client)
        encoder.writeUInt(self.clock)
    }

    public static func decode(_ decoder: Lib0Decoder) throws -> ID {
        return ID(
            client: try decoder.readUInt(),
            clock: try decoder.readUInt()
        )
    }
    
    public static func == (lhs: ID, rhs: ID) -> Bool {
        return lhs.client == rhs.client && lhs.clock == rhs.clock
    }
}
