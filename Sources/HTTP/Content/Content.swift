import Foundation

public protocol Content {
    static var mediaType: MediaType { get }
    static func parse(data: Data) throws -> Self
    func serialize() throws -> Data
}
