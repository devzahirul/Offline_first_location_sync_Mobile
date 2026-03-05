import Foundation
import Network

public actor NetworkMonitor {
    private var monitor: NWPathMonitor?
    private let queue: DispatchQueue

    private var started = false
    private var online = false

    private let statusStream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    public nonisolated var updates: AsyncStream<Bool> { statusStream }

    public init() {
        self.monitor = nil
        self.queue = DispatchQueue(label: "RTLSyncKit.NetworkMonitor")

        let (stream, continuation) = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(16))
        self.statusStream = stream
        self.continuation = continuation
    }

    public func start() {
        guard !started else { return }
        started = true

        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { await self?.setOnline(isOnline) }
        }
        newMonitor.start(queue: queue)
        monitor = newMonitor
    }

    public func stop() {
        monitor?.cancel()
        monitor = nil
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
