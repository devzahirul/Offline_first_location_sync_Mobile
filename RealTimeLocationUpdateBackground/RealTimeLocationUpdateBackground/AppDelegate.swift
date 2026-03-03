import Foundation
import RTLSyncKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        DemoSettings.ensureDefaults()

        let cfg = BackgroundProcessingConfiguration(
            taskIdentifier: BackgroundTaskIdentifiers.locationSync,
            requiresNetworkConnectivity: true,
            requiresExternalPower: false,
            earliestBeginAfter: 15 * 60,
            maxBatchesPerRun: 10
        )

        RTLSBackgroundSync.registerProcessingTask(configuration: cfg) {
            let settings = DemoSettings.load()
            let clientConfig = try settings.makeClientConfiguration()
            return try await LocationSyncClient(configuration: clientConfig)
        }

        do {
            try RTLSBackgroundSync.scheduleProcessingTask(configuration: cfg)
        } catch {
            print("BGTask schedule failed: \(String(describing: error))")
        }
        return true
    }
}
