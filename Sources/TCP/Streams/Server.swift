import Core
import Dispatch
import libc

/// A server socket can accept peers. Each accepted peer get's it own socket after accepting.
public final class Server: Core.OutputStream {
    // MARK: Stream
    public typealias Output = Client
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?

    // MARK: Internal

    let socket: Socket
    var readSource: SocketSource?

    /// Creates a TCP server from an existing TCP socket.
    public init(socket: Socket, workerCount: Int) {
        self.socket = socket
    }

    /// Creates a new Server Socket
    public convenience init(workerCount: Int = 8) throws {
        let socket = try Socket()
        self.init(socket: socket, workerCount: workerCount)
    }

    /// Starts listening for peers asynchronously
    ///
    /// - parameter maxIncomingConnections: The maximum backlog of incoming connections. Defaults to 4096.
    public func start(hostname: String = "localhost", port: UInt16, backlog: Int32 = 4096) throws {
        try socket.bind(hostname: hostname, port: port)
        try socket.listen(backlog: backlog)

        let source = socket.makeSource(.read, timeout: .never)
        source.onEvent {
            let socket: Socket
            do {
                socket = try self.socket.accept()
            } catch {
                self.errorStream?(error)
                return
            }

            let client = Client(socket: socket)
            client.errorStream = self.errorStream
            self.outputStream?(client)
        }

        source.onTimeout {
            fatalError("Server should not timeout.")
        }

        readSource = source
    }
}
