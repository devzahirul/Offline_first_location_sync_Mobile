//
//  RealTimeLocationUpdateBackgroundApp.swift
//  RealTimeLocationUpdateBackground
//
//  Created by lynkto_1 on 3/2/26.
//

import SwiftUI

@main
struct RealTimeLocationUpdateBackgroundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var vm = LocationSyncDemoViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .task {
                    vm.start()
                }
        }
    }
}
