//
//  Demangler.swift
//  RCBacktrace
//
//  Created by roy.cao on 2019/8/27.
//  Copyright © 2019 roy. All rights reserved.
//

enum Demangler {
    static func demangle(_ mangledName: String) -> String {
        mangledName.utf8CString.withUnsafeBufferPointer { str in
            guard let namePtr = _demangle(mangledName: str.baseAddress, length: UInt(str.count-1)) else {
                return mangledName
            }
            defer { namePtr.deallocate() }
            return String(cString: namePtr)
        }
    }
    
    static func humanReadableDemangle(_ mangledName: String) -> String {
        demangle(mangledName)
            .replacingOccurrences(of: "Swift.", with: "")
            .replacingOccurrences(of: "yswift.", with: "")
            .replacingOccurrences(of: "@owned ", with: "")
            .replacingOccurrences(of: "@unowned ", with: "")
            .replacingOccurrences(of: "@error ", with: "")
            .replacingOccurrences(of: "@callee_guaranteed ", with: "")
            .replacingOccurrences(of: "@in_guaranteed ", with: "")
            .replacingOccurrences(of: "@in_guaranteed ", with: "")
    }

    @_silgen_name("swift_demangle")
    private static func _demangle(
        mangledName: UnsafePointer<CChar>?, length: UInt,
        _: Int? = nil, _: Int? = nil, _: UInt32 = 0
    ) -> UnsafeMutablePointer<CChar>?
}
