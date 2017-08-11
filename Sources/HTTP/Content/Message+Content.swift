import Foundation

extension Message {
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

    public func serialize<C: Content>(_ content: C) throws {
        headers[.contentType] = C.mediaType.description
        body = try .data(content.serialize().makeBytes())
    }
}
