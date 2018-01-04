import Async
import Bits
import HTTP
import Foundation
import TCP
import XCTest

struct EchoWorker: HTTPResponder, Worker {
    let eventLoop: EventLoop

    init(on worker: Worker) {
        self.eventLoop = worker.eventLoop
    }

    func respond(to req: HTTPRequest, on Worker: Worker) throws -> Future<HTTPResponse> {
        /// simple echo server
        return Future(.init(body: req.body))
    }
}

class HTTPServerTests: XCTestCase {
    func testTCP() throws {
        let worker = try DefaultEventLoop(label: "codes.vapor.http.test.server")

        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpServer = try TCPServer(socket: tcpSocket)
        let server = HTTPServer<TCPClientStream, EchoWorker>(
            acceptStream: tcpServer.stream(on: worker),
            workers: [EchoWorker(on: worker)]
        )
        server.onError = { XCTFail("\($0)") }

        if #available(OSX 10.12, *) {
            Thread.detachNewThread {
                worker.runLoop()
            }
        } else {
            fatalError()
        }

        // beyblades let 'er rip
        try tcpServer.start(hostname: "localhost", port: 8123, backlog: 128)
        let exp = expectation(description: "all requests complete")

        var num = 1024
        for _ in 0..<num {
            let clientSocket = try TCPSocket(isNonBlocking: false)
            let client = try TCPClient(socket: clientSocket)
            try client.connect(hostname: "localhost", port: 8123)
            let write = Data("GET / HTTP/1.1\r\nContent-Length: 0\r\n\r\n".utf8)
            _ = try client.socket.write(write)
            let read = try client.socket.read(max: 512)
            client.close()
            let string = String(data: read, encoding: .utf8)
            XCTAssertEqual(string, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
            num -= 1
            if num == 0 {
                exp.fulfill()
            }
        }


        waitForExpectations(timeout: 5)
        tcpServer.stop()
    }

    static let allTests = [
        ("testTCP", testTCP),
    ]
}
