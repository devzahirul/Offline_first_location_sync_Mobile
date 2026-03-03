import SwiftUI
import RTLSyncKit

struct ContentView: View {
    @EnvironmentObject private var vm: LocationSyncDemoViewModel

    @AppStorage(DemoDefaults.baseURL) private var baseURL: String = "http://192.168.0.103:3000"
    @AppStorage(DemoDefaults.accessToken) private var accessToken: String = ""
    @AppStorage(DemoDefaults.userId) private var userId: String = "user_123"
    @AppStorage(DemoDefaults.deviceId) private var deviceId: String = ""

    @AppStorage(DemoDefaults.policyType) private var policyTypeRaw: String = DemoSettings.PolicyType.distance.rawValue
    @AppStorage(DemoDefaults.distanceMeters) private var distanceMeters: Double = 25
    @AppStorage(DemoDefaults.timeIntervalSeconds) private var timeIntervalSeconds: Double = 5

    @AppStorage(DemoDefaults.batchMaxSize) private var batchMaxSize: Int = 50
    @AppStorage(DemoDefaults.flushIntervalSeconds) private var flushIntervalSeconds: Double = 10
    @AppStorage(DemoDefaults.maxBatchAgeSeconds) private var maxBatchAgeSeconds: Double = 60
    @AppStorage(DemoDefaults.useSignificantLocationChanges) private var useSignificantLocationChanges: Bool = false

    private var policyType: DemoSettings.PolicyType {
        DemoSettings.PolicyType(rawValue: policyTypeRaw) ?? .distance
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    content
                        .navigationTitle("RTLS Demo")
                }
            } else {
                NavigationView {
                    content
                        .navigationBarTitle("RTLS Demo", displayMode: .inline)
                }
            }
        }
        .onAppear {
            if deviceId.isEmpty {
                DemoSettings.ensureDefaults()
                deviceId = DemoDefaults.suite.string(forKey: DemoDefaults.deviceId) ?? ""
            }
            vm.refreshIfReady()
        }
    }

    private var content: some View {
        List {
            Section("Status") {
                KeyValueRow("Authorization") { Text(String(describing: vm.authorization)) }
                KeyValueRow("Tracking") { Text(vm.isTracking ? "Running" : "Stopped") }
                if vm.isTracking && useSignificantLocationChanges {
                    Text("Updates only when you move ~500 m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                KeyValueRow("Last Sync") { Text(vm.lastSyncMessage) }
                KeyValueRow("Pending Queue") {
                    if vm.isClientReady {
                        Text("\(vm.pendingCount)")
                    } else {
                        Text("…")
                            .foregroundStyle(.secondary)
                    }
                }

                if let oldest = vm.oldestPendingRecordedAt {
                    KeyValueRow("Oldest Pending") {
                        Text(oldest.formatted())
                            .font(.caption)
                    }
                }

                if let p = vm.lastRecorded {
                    KeyValueRow("Last Recorded") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(p.coordinate.latitude), \(p.coordinate.longitude)")
                                .font(.caption)
                            Text(p.recordedAt.formatted())
                                .font(.caption2)
                        }
                    }
                }

                if let msg = vm.errorMessage, !msg.isEmpty {
                    Text(msg)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            Section("Backend") {
                TextField("Base URL (http/https)", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                TextField("Access Token (optional)", text: $accessToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("User ID", text: $userId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Device ID", text: $deviceId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Apply Settings (Rebuild Client)") {
                    DemoSettings(
                        baseURL: baseURL,
                        accessToken: accessToken,
                        userId: userId,
                        deviceId: deviceId.isEmpty ? UUID().uuidString : deviceId,
                        policyType: policyType,
                        distanceMeters: distanceMeters,
                        timeIntervalSeconds: timeIntervalSeconds,
                        batchMaxSize: batchMaxSize,
                        flushIntervalSeconds: flushIntervalSeconds,
                        maxBatchAgeSeconds: maxBatchAgeSeconds,
                        useSignificantLocationChanges: useSignificantLocationChanges
                    ).save()

                    if deviceId.isEmpty {
                        deviceId = DemoDefaults.suite.string(forKey: DemoDefaults.deviceId) ?? ""
                    }

                    vm.rebuildClient()
                }
            }

            Section("Tracking Policy") {
                Toggle("Significant location only (wakes app after terminate)", isOn: $useSignificantLocationChanges)

                Picker("Mode", selection: $policyTypeRaw) {
                    Text("Distance").tag(DemoSettings.PolicyType.distance.rawValue)
                    Text("Time").tag(DemoSettings.PolicyType.time.rawValue)
                }
                .pickerStyle(.segmented)

                switch policyType {
                case .distance:
                    HStack {
                        Text("Meters")
                        Spacer()
                        TextField("", value: $distanceMeters, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 120)
                    }

                case .time:
                    HStack {
                        Text("Interval (s)")
                        Spacer()
                        TextField("", value: $timeIntervalSeconds, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 120)
                    }
                }
            }

            Section("Batch Sync") {
                Stepper("Max batch: \(batchMaxSize)", value: $batchMaxSize, in: 1...500)

                HStack {
                    Text("Flush interval (s)")
                    Spacer()
                    TextField("", value: $flushIntervalSeconds, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: 120)
                }

                HStack {
                    Text("Max batch age (s)")
                    Spacer()
                    TextField("", value: $maxBatchAgeSeconds, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: 120)
                }
            }

            Section("Actions") {
                HStack {
                    Button("When In Use") { vm.requestWhenInUseAuthorization() }
                    Spacer()
                    Button("Always") { vm.requestAlwaysAuthorization() }
                }

                Button(vm.isTracking ? "Stop Tracking" : "Start Tracking") {
                    vm.toggleTracking()
                }

                Button("Flush Now") {
                    vm.flushNow()
                }

                Button("Refresh Stats") {
                    Task { await vm.refreshStats() }
                }
            }

            Section("Map") {
                NavigationLink("Live Map") {
                    LiveMapView()
                }
                NavigationLink("Pending locations (\(vm.isClientReady ? "\(vm.pendingCount)" : "…")") {
                    PendingLocationsView()
                }
            }

            Section("Subscriber (Realtime Watch)") {
                TextField("Watch userId", text: $vm.subscriberUserId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Button(vm.isSubscriberRunning ? "Stop" : "Start") {
                        if vm.isSubscriberRunning {
                            vm.stopSubscriber()
                        } else {
                            vm.startSubscriber()
                        }
                    }
                    Spacer()
                    if let p = vm.lastSubscribedPoint {
                        Text("\(p.coordinate.latitude), \(p.coordinate.longitude)")
                            .font(.caption)
                    } else {
                        Text("—")
                            .font(.caption)
                    }
                }
            }

            Section("Logs") {
                ForEach(vm.logs, id: \.self) { line in
                    Text(line)
                        .font(.caption2)
                        .textSelection(.enabled)
                        .lineLimit(3)
                }
            }
        }
    }
}

#Preview {
    let vm = LocationSyncDemoViewModel()
    return ContentView()
        .environmentObject(vm)
}
