//
//  SoulMarkApp.swift
//  SoulMark
//
//  Created by JJ Zhang on 2026/8/3.
//

import SwiftUI

@main
struct SoulMarkApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.route {
                case .launch:
                    SoulLaunchView()
                case .authentication:
                    AuthenticationView()
                case .onboarding:
                    SoulOnboardingView()
                case .main:
                    ContentView()
                }
            }
            .environmentObject(session)
            .preferredColorScheme(isSoulNightMode() ? .dark : .light)
            .task {
                if session.route == .launch {
                    await session.bootstrap()
                }
            }
        }
    }
}
