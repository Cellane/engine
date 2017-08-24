import Core
import Dispatch
import Foundation
import libc

/// TCP client stream.
public final class Client: Core.Stream {
    // MARK: Stream
    public typealias Input = DispatchData
    public typealias Output = ByteBuffer
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?

    /// The client stream's underlying socket.
    public let socket: Socket

    // Bytes from the socket are read into this buffer.
    // Views into this buffer supplied to output streams.
    let outputBuffer: MutableByteBuffer

    // Data being fed into the client stream is stored here.
    var inputBuffer: DispatchData?

    // Stores read event source.
    var readSource: SocketSource?

    // Stores write event source.
    var writeSource: SocketSource?

    /// Creates a new Remote Client from the ServerSocket's details
    public init(socket: Socket) {
        self.socket = socket

        // Allocate one TCP packet
        let size = 65_507
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        self.outputBuffer = MutableByteBuffer(start: pointer, count: size)
    }

    // MARK: Stream

    public var onClose: (() -> ())?

    /// Handles stream input
    public func inputStream(_ input: DispatchData) {
        if inputBuffer == nil {
            inputBuffer = input
            writeSource?.resume()
        } else {
            inputBuffer?.append(input)
        }

        if writeSource == nil {
            let source = socket.makeSource(.write, timeout: .seconds(30))

            source.onEvent {
                // important: make sure to suspend or else writeable
                // will keep calling.
                self.writeSource?.suspend()

                // grab input buffer
                guard let data = self.inputBuffer else {
                    return
                }
                self.inputBuffer = nil

                // copy input into contiguous data and write it.
                let copied = Data(data)
                let buffer = ByteBuffer(start: copied.withUnsafeBytes { $0 }, count: copied.count)
                do {
                    _ = try self.socket.write(max: copied.count, from: buffer)
                    // FIXME: we should verify the lengths match here.
                } catch {
                    // any errors that occur here cannot be thrown,
                    // so send them to stream error catcher.
                    self.errorStream?(error)
                }
            }

            source.onTimeout {
                self.close()
            }

            writeSource = source
        }

    }

    /// Starts receiving data from the client
    public func start() {
        let source = socket.makeSource(.read, timeout: .seconds(30))

        source.onTimeout {
            self.close()
        }

        source.onEvent {
            let read: Int
            do {
                read = try self.socket.read(
                    max: self.outputBuffer.count,
                    into: self.outputBuffer
                )
            } catch {
                // any errors that occur here cannot be thrown,
                // so send them to stream error catcher.
                self.errorStream?(error)
                return
            }

            // create a view into our internal buffer and
            // send to the output stream
            let bufferView = ByteBuffer(
                start: self.outputBuffer.baseAddress,
                count: read
            )
            self.outputStream?(bufferView)
        }

        readSource = source
    }

    /// Closes the client.
    public func close() {
        // print("\(socket.descriptor.raw) socket.close()")
        socket.close()
        // important! client will not be deallocated if this 
        outputStream = nil
        readSource?.cancel()
        writeSource?.cancel()
        readSource = nil
        writeSource = nil
        onClose?()
    }

    /// Deallocated the pointer buffer
    deinit {
        // print("deinit")
        close()
        outputBuffer.baseAddress.unsafelyUnwrapped.deinitialize(count: outputBuffer.count)
        outputBuffer.baseAddress.unsafelyUnwrapped.deallocate(capacity: outputBuffer.count)
    }
}

