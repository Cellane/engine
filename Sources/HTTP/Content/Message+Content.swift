import Foundation

extension Message {
    /// Parses the specified content type from the HTTP message.
    ///
    /// Note: If the HTTP message's content type does not equal the
    /// desired type, nil will be returned.
    ///
    /// Errors will be thrown if there is a malformed content type or
    /// body data.
    public func parse<C: Content>(_ type: C.Type = C.self) throws -> C? {
        guard let contentType = headers[.contentType] else {
            return nil
        }

        let mediaType = try MediaType(string: contentType)
        guard C.mediaType == mediaType else {
            return nil
        }

        guard let bytes = body.bytes else {
            return nil
        }

        let data = Data(bytes)
        return try C.parse(data: data)
    }

    /// Serializes the specified content to the HTTP message
    /// and sets the appopriate content type and length headers.
    public func serialize<C: Content>(_ content: C) throws {
        let bytes = try content.serialize().makeBytes()
        headers[.contentType] = C.mediaType.description
        headers[.contentLength] = bytes.count.description
        body = .data(bytes)

    }
}
