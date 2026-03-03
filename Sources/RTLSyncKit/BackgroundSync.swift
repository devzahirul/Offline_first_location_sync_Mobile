import Foundation

#if canImport(BackgroundTasks) && os(iOS)
import BackgroundTasks

public struct BackgroundProcessingConfiguration: Sendable, Equatable {
    /// Must also be listed in the host app's `BGTaskSchedulerPermittedIdentifiers`.
    public var taskIdentifier: String

    public var requiresNetworkConnectivity: Bool
    public var requiresExternalPower: Bool

    /// Best-effort: the system may run later than this.
    public var earliestBeginAfter: TimeInterval

    /// Limits work per run to fit inside background execution time budgets.
    public var maxBatchesPerRun: Int?

    public init(
        taskIdentifier: String,
        requiresNetworkConnectivity: Bool = true,
        requiresExternalPower: Bool = false,
        earliestBeginAfter: TimeInterval = 15 * 60,
        maxBatchesPerRun: Int? = 10
    ) {
        self.taskIdentifier = taskIdentifier
        self.requiresNetworkConnectivity = requiresNetworkConnectivity
        self.requiresExternalPower = requiresExternalPower
        self.earliestBeginAfter = earliestBeginAfter
        self.maxBatchesPerRun = maxBatchesPerRun
    }
}

/// Thin wrapper around `BGTaskScheduler` to run `LocationSyncClient.flushNow()` in the background.
///
/// The host app must:
/// - enable Background Modes (Background fetch and/or Background processing as needed)
/// - add `BGTaskSchedulerPermittedIdentifiers` to Info.plist
/// - call `registerProcessingTask(...)` at launch
/// - call `scheduleProcessingTask(...)` before entering background (and optionally on launch)
public enum RTLSBackgroundSync {
    public static func registerProcessingTask(
        configuration: BackgroundProcessingConfiguration,
        client: LocationSyncClient
    ) {
        registerProcessingTask(configuration: configuration) {
            client
        }
    }

    public static func registerProcessingTask(
        configuration: BackgroundProcessingConfiguration,
        makeClient: @escaping @Sendable () async throws -> LocationSyncClient
    ) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: configuration.taskIdentifier, using: nil) { task in
            guard let processing = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }

            // Re-schedule early so the system keeps granting opportunities.
            try? scheduleProcessingTask(configuration: configuration)

            let flushTask = Task {
                do {
                    let client = try await makeClient()
                    await client.flushNow(maxBatches: configuration.maxBatchesPerRun)
                    processing.setTaskCompleted(success: !Task.isCancelled)
                } catch {
                    processing.setTaskCompleted(success: false)
                }
            }

            processing.expirationHandler = {
                flushTask.cancel()
            }
        }
    }

    public static func scheduleProcessingTask(configuration: BackgroundProcessingConfiguration) throws {
        let request = BGProcessingTaskRequest(identifier: configuration.taskIdentifier)
        request.requiresNetworkConnectivity = configuration.requiresNetworkConnectivity
        request.requiresExternalPower = configuration.requiresExternalPower
        request.earliestBeginDate = Date(timeIntervalSinceNow: max(1, configuration.earliestBeginAfter))

        try BGTaskScheduler.shared.submit(request)
    }
}
#endif
