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
            ZStack {
                routeContent
                    .id(session.route)
                    .transition(rootRouteTransition)
            }
            .background {
                GlobalKeyboardDismissalInstaller()
                    .frame(width: 0, height: 0)
            }
            .animation(.smooth(duration: 0.48), value: session.route)
            .environmentObject(session)
            .preferredColorScheme(isSoulNightMode() ? .dark : .light)
            .task {
                if session.route == .launch {
                    await session.bootstrap()
                }
            }
        }
    }

    @ViewBuilder
    private var routeContent: some View {
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

    private var rootRouteTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985)),
            removal: .opacity.combined(with: .scale(scale: 1.015))
        )
    }
}
