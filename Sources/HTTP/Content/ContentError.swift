/// Errors that can be thrown while working
/// with HTTP content.
public struct ContentError : Error {
    /// The reason this error occurred.
    public let reason: String

    /// Creates a new ContentError.
    init(reason: String) {
        self.reason = reason
    }
}
