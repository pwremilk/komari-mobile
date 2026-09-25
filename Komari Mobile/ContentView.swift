//
//  ContentView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: KMState
    @State private var isShowingOnboarding: Bool = false

    var body: some View {
        Group {
            if isShowingOnboarding {
                OnboardingView(isShowingOnboarding: $isShowingOnboarding)
                    .transition(.opacity)
            } else {
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.5), value: isShowingOnboarding)
        .onAppear {
            if KMCore.isKomariDashboardConfigured {
                state.loadDashboard()
            } else {
                isShowingOnboarding = true
            }
        }
    }
}
