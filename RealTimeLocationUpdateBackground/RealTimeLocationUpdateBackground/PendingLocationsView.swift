import SwiftUI
import RTLSyncKit

struct PendingLocationsView: View {
    @EnvironmentObject private var vm: LocationSyncDemoViewModel

    var body: some View {
        List {
            Section {
                Text("\(vm.pendingPointsList.count) pending (not yet uploaded)")
                    .font(.subheadline)
            }
            Section("Pending locations") {
                if vm.pendingPointsList.isEmpty {
                    Text("No pending points.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.pendingPointsList, id: \.id) { p in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.recordedAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption.bold())
                            Text(String(format: "%.5f, %.5f", p.coordinate.latitude, p.coordinate.longitude))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Pending locations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await vm.loadPendingPoints() }
        }
        .refreshable {
            await vm.loadPendingPoints()
        }
    }
}
