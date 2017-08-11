import Foundation

/// Types conforming to this protocol can be used
/// to extract content from HTTP message bodies.
public protocol Content {
    /// See MediaType
    static var mediaType: MediaType { get }

    /// Parses the body data into content.
    static func parse(data: Data) throws -> Self

    /// Serializes the content into body data.
    func serialize() throws -> Data
}
