import Vapor

extension Request {
    public func get(_ key: String)throws -> Codable? {
        let storage = try self.privateContainer.make(Storage.self, for: Request.self)
        return storage.cache[key]
    }
    
    public func set(_ key: String, to value: Codable)throws {
        var storage = try self.privateContainer.make(Storage.self, for: Request.self)
        storage.cache[key] = value
    }
}
