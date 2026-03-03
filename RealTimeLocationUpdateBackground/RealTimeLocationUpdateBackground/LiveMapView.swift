import CoreLocation
import SwiftUI

struct LiveMapView: View {
    @EnvironmentObject private var vm: LocationSyncDemoViewModel

    @State private var followMode: FollowMode = .device
    @State private var fitTrigger = UUID()

    enum FollowMode: String, CaseIterable, Identifiable {
        case none = "None"
        case device = "Device"
        case watched = "Watched"

        var id: String { rawValue }
    }

    private var followCoordinate: CLLocationCoordinate2D? {
        switch followMode {
        case .none:
            return nil
        case .device:
            return vm.recordedPath.last
        case .watched:
            return vm.subscribedPath.last
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            RTLSMapViewRepresentable(
                recordedPath: vm.recordedPath,
                subscribedPath: vm.subscribedPath,
                followCoordinate: followCoordinate,
                fitTrigger: fitTrigger
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    legendPill(color: .blue, text: "Device")
                    legendPill(color: .red, text: "Watched")
                    Spacer()
                    Text("Pending \(vm.pendingCount)")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                HStack(spacing: 10) {
                    Button(vm.isTracking ? "Stop" : "Start") {
                        vm.toggleTracking()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Flush") {
                        vm.flushNow()
                    }
                    .buttonStyle(.bordered)

                    Button("Fit") {
                        fitTrigger = UUID()
                    }
                    .buttonStyle(.bordered)

                    Button("Clear") {
                        vm.clearMapPaths()
                    }
                    .buttonStyle(.bordered)
                }

                Picker("Follow", selection: $followMode) {
                    ForEach(FollowMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
        }
        .navigationTitle("Live Map")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legendPill(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

#Preview {
    let vm = LocationSyncDemoViewModel()
    return NavigationView {
        LiveMapView()
            .environmentObject(vm)
    }
}

