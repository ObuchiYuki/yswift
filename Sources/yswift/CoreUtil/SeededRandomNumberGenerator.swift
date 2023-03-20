//
//  File.swift
//  
//
//  Created by yuki on 2023/03/18.
//

// XorShift
public struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var x: UInt32 = 123456789
    private var y: UInt32 = 362436069
    private var z: UInt32 = 521288629
    private var w: UInt32
    
    public init(seed: UInt32) {
        self.w = seed
    }
    
    private mutating func make() -> UInt32 {
        let t = self.x ^ (self.x << 11)
        self.x = self.y
        self.y = self.z
        self.z = self.w
        self.w = (self.w ^ (self.w >> 19)) ^ (t ^ (t >> 8))
        return self.w
    }
    
    public mutating func next() -> UInt64 {
        print("have random")
        let lower = UInt64(make())
        let upper = UInt64(make())
        
        return lower << 32 + upper
    }
}
