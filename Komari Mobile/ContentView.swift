//
//  ContentView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state
    @State private var isShowingOnboarding: Bool = false

    var body: some View {
        Group {
            if isShowingOnboarding {
                OnboardingView(isShowingOnboarding: $isShowingOnboarding)
                    .transition(.blurReplace)
            } else {
                HomeView()
                    .transition(.blurReplace)
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
