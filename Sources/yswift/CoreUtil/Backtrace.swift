//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final public class Backtrace: CustomStringConvertible {
    final public class Symbol: CustomStringConvertible {
        public let moduleName: String
        public let address: String
        public let mangledName: String
        public let offset: Int?
        public lazy var symbolName = Demangler.humanReadableDemangle(self.mangledName)
        
        public var description: String {
            "\(moduleName)\t\t\t\(symbolName)"
        }
        
        init(_ symbol: String) {
            let components = symbol
                .components(separatedBy: .whitespaces)
                .filter{ !$0.isEmpty }
                        
            self.moduleName = components[1].replacingOccurrences(of: ".dylib", with: "")
            self.address = components[2]
            self.mangledName = components[3..<components.count-2].joined(separator: " ")
            self.offset = Int(components[5])
        }
    }
    
    private let symbols: [Backtrace.Symbol]
    private var omitSymbolCount: Int
    static let testing: Bool = NSClassFromString("XCTest") != nil
    
    public var description: String {
        let symbolList = symbols
            .enumerated()
            .map{ "\($0)\t\($1.description)" }
            .joined(separator: "\n")

        return "\(symbolList)\n...omitting \(omitSymbolCount) symbols."
        
    }
    
    public init(dropFirstSymbols: Int = 0) {
        let symbols = Thread.callStackSymbols
            .map{ Backtrace.Symbol($0) }
            .dropFirst(2 + dropFirstSymbols)
                
        if Backtrace.testing {
            var nsymbols = [Symbol]()
            for symbol in symbols {
                if symbol.moduleName == "XCTestCore" { break }
                nsymbols.append(symbol)
            }
            self.symbols = nsymbols
            self.omitSymbolCount = symbols.count - nsymbols.count
        } else {
            self.symbols = symbols.map{ $0 }
            self.omitSymbolCount = 0
        }
    }
}
