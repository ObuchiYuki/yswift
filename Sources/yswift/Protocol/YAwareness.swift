
import Foundation
import Combine
import lib0

private let outdatedTimeout: TimeInterval = 30000

public protocol YAwarenessValue: Codable {
    init()
}

final public class YAwareness<State: YAwarenessValue> {
    public struct Update {
        public let added: [Int]
        public let updated: [Int]
        public let removed: [Int]
    }
    
    private struct ClientMeta {
        let clock: Int
        let lastUpdated: Double
    }
        
    public let document: YDocument
    public let clientID: Int
    
    public var states: [Int: State] = [:]
    
    public var updatePublisher: some Publisher<Update, Never> { _updatePublisher }
    public var changePublisher: some Publisher<Update, Never> { _changePublisher }
    
    private var meta: [Int: ClientMeta] = [:]

    private let _updatePublisher = PassthroughSubject<Update, Never>()
    private let _changePublisher = PassthroughSubject<Update, Never>()
    private var _checkTimer: Timer!

    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    public init(_ document: YDocument) {
        self.document = document
        self.clientID = document.clientID
        
        self._checkTimer = Timer.scheduledTimer(withTimeInterval: outdatedTimeout / 10, repeats: true) {[weak self] timer in
            guard let self = self else { return timer.invalidate() }
            let now = Date().timeIntervalSince1970
            guard let meta = self.meta[self.clientID] else { return }

            if outdatedTimeout / 2 <= now - meta.lastUpdated {
                self.localState = self.localState
            }
            let removedClients = self.meta
                .filter{ (client, meta) in client != self.clientID && outdatedTimeout <= now - meta.lastUpdated && self.states[client] != nil }
                .map{ $0.key }
            
            if removedClients.count > 0 {
                self._removeStates(of: removedClients)
            }
        }
        
        document.on(YDocument.On.destroy) {
            self._checkTimer.invalidate()
        }
        
        self.localState = .init()
    }

    public var localState: State {
        get { self.states[self.clientID] ?? .init() }
        set { self._updateState(newValue) }
    }

    public func applyUpdate(_ update: Data) throws {
        let decoder = LZDecoder(update)
        let timestamp = Date().timeIntervalSince1970
        var added = [Int](), updated = [Int](), removed = [Int](), filteredUpdated = [Int]()
        
        for _ in 0..<(try decoder.readUInt()) {
            let clientID = Int(try decoder.readUInt())
            var clock = Int(try decoder.readUInt())
            let state = try self.jsonDecoder.decode(Optional<State>.self, from: decoder.readData())
            let clientMeta = self.meta[clientID]
            let prevState = self.states[clientID]
            let currentClock = clientMeta.map{ $0.clock } ?? 0

            if currentClock < clock || (currentClock == clock && state == nil && self.states[clientID] != nil) {
                if state == nil {
                    if clientID == self.clientID {
                        clock += 1
                    } else {
                        self.states.removeValue(forKey: clientID)
                    }
                } else {
                    self.states[clientID] = state
                }
                self.meta[clientID] = ClientMeta(clock: clock, lastUpdated: timestamp)
                
                if clientMeta == nil && state != nil {
                    added.append(clientID)
                } else if clientMeta != nil && state == nil {
                    removed.append(clientID)
                } else if state != nil {
                    if !equalJSON(state, prevState) { filteredUpdated.append(clientID) }
                    updated.append(clientID)
                }
            }
        }
        
        if added.count > 0 || filteredUpdated.count > 0 || removed.count > 0 {
            self._changePublisher.send(Update(added: added, updated: filteredUpdated, removed: removed))
        }
        if added.count > 0 || updated.count > 0 || removed.count > 0 {
            self._updatePublisher.send(Update(added: added, updated: updated, removed: removed))
        }
    }

    public func encodeUpdate(of clients: [Int]) throws -> Data? {
        let encoder = LZEncoder()
        encoder.writeUInt(UInt(clients.count))
        
        for clientID in clients {
            let state = states[clientID]
            guard let clock = self.meta[clientID]?.clock else { return nil }
            encoder.writeUInt(UInt(clientID))
            encoder.writeUInt(UInt(clock))
            let data = try self.jsonEncoder.encode(state)
            encoder.writeData(data)
        }
        return encoder.data
    }
    
    private func _updateState(_ newValue: State?) {
        let clock = self.meta[clientID].map{ $0.clock + 1 } ?? 0
        let prevState = self.states[clientID]

        if newValue == nil {
            self.states.removeValue(forKey: clientID)
        } else {
            self.states[clientID] = newValue
        }
        self.meta[clientID] = ClientMeta(clock: clock, lastUpdated: Date().timeIntervalSince1970)

        var added = [Int](), updated = [Int](), removed = [Int](), filteredUpdated = [Int]()
        
        if newValue == nil {
            removed.append(clientID)
        } else if prevState == nil {
            if newValue != nil { added.append(clientID) }
        } else {
            updated.append(clientID)
            if !equalJSON(prevState, newValue) { filteredUpdated.append(clientID) }
        }
        if added.count > 0 || filteredUpdated.count > 0 || removed.count > 0 {
            self._changePublisher.send(Update(added: added, updated: filteredUpdated, removed: removed))
        }
        self._updatePublisher.send(Update(added: added, updated: updated, removed: removed))
    }
    
    private func _removeStates(of clients: [Int]){
        var removed: [Int] = []
        for clientID in clients where self.states[clientID] != nil {
            self.states.removeValue(forKey: clientID)
            
            if clientID == self.clientID {
                guard let meta = self.meta[clientID] else { continue }
                self.meta[clientID] = ClientMeta(clock: meta.clock + 1, lastUpdated: Date().timeIntervalSince1970)
            }
            removed.append(clientID)
        }
        if removed.count > 0 {
            self._changePublisher.send(Update(added: [], updated: [], removed: removed))
            self._updatePublisher.send(Update(added: [], updated: [], removed: removed))
        }
    }
}




//public func modifyUpdate(_ update: Data, modify: (Any) -> Any) throws -> Data {
//    let decoder = LZDecoder(update)
//    let encoder = LZEncoder()
//    let len = try decoder.readUInt()
//    encoder.writeUInt(len)
//    for _ in 0..<len {
//        let clientID = try decoder.readUInt()
//        let clock = try decoder.readUInt()
//        let state = try JSONSerialization.jsonObject(with: decoder.readData())
//        let modifiedState = modify(state)
//        encoder.writeUInt(clientID)
//        encoder.writeUInt(clock)
//        encoder.writeData(try JSONSerialization.data(withJSONObject: modifiedState))
//    }
//    return encoder.data
//}
