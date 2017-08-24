import Dispatch

/// A socket event.
public typealias SocketEvent = () -> ()

public final class SocketSource {
    public enum Kind {
        case read
        case write
    }

    private let timer: DispatchSourceTimer
    private let source: DispatchSourceProtocol
    private let timeout: DispatchTimeInterval

    public init(_ type: Kind, descriptor: Descriptor, timeout: DispatchTimeInterval) {
        let source: DispatchSourceProtocol

        switch type {
        case .read:
            source = DispatchSource.makeReadSource(fileDescriptor: descriptor.raw)
        case .write:
            source = DispatchSource.makeWriteSource(fileDescriptor: descriptor.raw)
        }

        self.source = source
        self.timeout = timeout
        self.timer = DispatchSource.makeTimerSource()
        _scheduleTimeout()
        timer.resume()
        source.resume()
    }

    public func onEvent(event: @escaping SocketEvent) {
        source.setEventHandler {
            self._scheduleTimeout()
            event()
        }
    }

    public func onTimeout(event: @escaping SocketEvent) { 
        timer.setEventHandler {
            event()
            self.source.cancel()
            self.timer.cancel()
        }
    }

    public func resume() {
        self.timer.resume()
        self.source.resume()
    }

    public func suspend() {
        self.timer.suspend()
        self.source.suspend()
    }

    public func cancel() {
        self.timer.cancel()
        self.source.cancel()
    }

    private func _scheduleTimeout() {
        timer.schedule(deadline: .now() + timeout)
    }

    deinit {
        // print("deinit socket source")
    }
}

extension Socket {
    /// The socket event will be called on the supplied queue
    /// whenever this socket can be read from.
    public func makeSource(_ type: SocketSource.Kind, timeout: DispatchTimeInterval) -> SocketSource {
        return SocketSource(type, descriptor: descriptor, timeout: timeout)
    }
}
