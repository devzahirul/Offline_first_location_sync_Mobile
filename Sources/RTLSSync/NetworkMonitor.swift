import Foundation
import Network

public actor NetworkMonitor {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    private var started = false
    private var online = false

    private let statusStream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    public nonisolated var updates: AsyncStream<Bool> { statusStream }

    public init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "RTLSyncKit.NetworkMonitor")

        let (stream, continuation) = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(16))
        self.statusStream = stream
        self.continuation = continuation
    }

    public func start() {
        guard !started else { return }
        started = true

        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { await self?.setOnline(isOnline) }
        }

        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
        started = false
    }

    public func isOnline() -> Bool {
        online
    }

    private func setOnline(_ value: Bool) {
        online = value
        continuation.yield(value)
    }
}

