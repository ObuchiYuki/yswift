//
//  File.swift
//  
//
//  Created by yuki on 2023/03/18.
//

public class RandomGenerator {
    private var x: Int32 = 123456789
    private var y: Int32 = 362436069
    private var z: Int32 = 521288629
    private var w: Int32
    
    public init(seed: Int32) {
        self.w = seed
    }
    
    func next() -> Double {
        let t = self.x ^ (self.x << 11)
        self.x = self.y
        self.y = self.z
        self.z = self.w
        self.w = (self.w ^ (self.w >> 19)) ^ (t ^ (t >> 8))
        return Double(self.w) / Double(0x7FFFFFFF)
    }
    
    public func bool() -> Bool {
        return self.next() >= 0.5
    }
    public func int(min: Int, max: Int) -> Int {
        Int(self.next() * Double(max + 1 - min)) + min
    }
    public func int(in range: ClosedRange<Int>) -> Int {
        return int(min: range.lowerBound, max: range.upperBound)
    }
    public func oneOf<T>(_ elements: [T]) -> T {
        elements[self.int(in: 0...elements.count-1)]
    }
}
