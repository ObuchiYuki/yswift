//
//  File.swift
//  
//
//  Created by yuki on 2023/03/18.
//

import Foundation
import yswift

enum Sync {
    typealias StateMap = [Int: Int]

    enum MessageType: UInt {
        case syncStep1 = 0
        case syncStep2 = 1
        case update = 2
    }

    static func writeSyncStep1(encoder: LZEncoder, doc: Doc) throws {
        encoder.writeUInt(MessageType.syncStep1.rawValue)
        let sv = try doc.encodeStateVector()
        encoder.writeData(sv)
    }

    static func writeSyncStep2(encoder: LZEncoder, doc: Doc, encodedStateVector: Data? = nil) throws {
        encoder.writeUInt(MessageType.syncStep2.rawValue)
        let update = try doc.encodeStateAsUpdate(encodedStateVector: encodedStateVector)
                
        encoder.writeData(update)
    }

    static func readSyncStep1(decoder: LZDecoder, encoder: LZEncoder, doc: Doc) throws {
        try writeSyncStep2(encoder: encoder, doc: doc, encodedStateVector: decoder.readData())
    }

    static func readSyncStep2(decoder: LZDecoder, doc: Doc, transactionOrigin: Any? = nil) {
        do {
            let data = try decoder.readData()
            try doc.applyUpdate(data, transactionOrigin: transactionOrigin)
        } catch {
            print("Caught error while handling a Yjs update. \(error)")
        }
    }

    static func writeUpdate(encoder: LZEncoder, update: Data) {
        encoder.writeUInt(MessageType.update.rawValue)
        encoder.writeData(update)
    }

    static func readUpdate_(decoder: LZDecoder, doc: Doc, transactionOrigin: Any? = nil) {
        readSyncStep2(decoder: decoder, doc: doc, transactionOrigin: transactionOrigin)
    }

    @discardableResult
    static func readSyncMessage(decoder: LZDecoder, encoder: LZEncoder, doc: Doc, transactionOrigin: Any? = nil) throws -> MessageType {
        let messageType = MessageType(rawValue: try decoder.readUInt())!
        
        
        switch messageType {
        case .syncStep1:
            try self.readSyncStep1(decoder: decoder, encoder: encoder, doc: doc)
        case .syncStep2:
            self.readSyncStep2(decoder: decoder, doc: doc, transactionOrigin: transactionOrigin)
        case .update:
            self.readUpdate_(decoder: decoder, doc: doc, transactionOrigin: transactionOrigin)
        }
        
        return messageType
    }


}
