//
//  OnboardingView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/18/26.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var state
    @Binding var isShowingOnboarding: Bool
    @State private var currentPage = 0

    // Connect form fields
    @State private var link = ""
    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var isSSLEnabled = true
    @State private var useAPIKey = false

    private let totalPages = 4

    private var canConnect: Bool {
        if link.isEmpty { return false }
        if useAPIKey {
            return !apiKey.isEmpty
        } else {
            return !username.isEmpty && !password.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                if currentPage < totalPages - 1 {
                    Button("Skip") {
                        withAnimation(.spring(duration: 0.4)) {
                            currentPage = totalPages - 1
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .animation(.smooth, value: currentPage)

            // Pages
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                monitoringPage.tag(1)
                chartsPage.tag(2)
                connectPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom controls
            VStack(spacing: 20) {
                OnboardingPageDots(current: currentPage, total: totalPages)

                Group {
                    if currentPage < totalPages - 1 {
                        Button {
                            withAnimation(.spring(duration: 0.4)) {
                                currentPage += 1
                            }
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor, in: Capsule())
                        }
                        .transition(.blurReplace)
                    } else {
                        Button {
                            connect()
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(canConnect ? Color.accentColor : Color.gray, in: Capsule())
                        }
                        .disabled(!canConnect)
                        .transition(.blurReplace)
                    }
                }
                .animation(.smooth, value: currentPage)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Feature Pages

    private var welcomePage: some View {
        OnboardingFeaturePage(
            icon: "server.rack",
            iconColor: .blue,
            title: "Welcome to Komari",
            description: "Your servers at your fingertips.\nMonitor, analyze, and stay in control."
        )
    }

    private var monitoringPage: some View {
        OnboardingFeaturePage(
            icon: "gauge.with.dots.needle.67percent",
            iconColor: .green,
            title: "Real-time Monitoring",
            description: "Track CPU, memory, disk, and network performance — all updating live."
        )
    }

    private var chartsPage: some View {
        OnboardingFeaturePage(
            icon: "chart.xyaxis.line",
            iconColor: .purple,
            title: "Performance Charts",
            description: "Visualize load trends and ping latency with detailed historical charts."
        )
    }

    // MARK: - Connect Page

    private var connectPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue.gradient)
                    .symbolRenderingMode(.hierarchical)
                    .padding(.top, 20)

                VStack(spacing: 6) {
                    Text("Connect Dashboard")
                        .font(.system(.title2, design: .rounded, weight: .bold))

                    Text("Enter your Komari dashboard details.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    onboardingField(icon: "globe", placeholder: "komari.hidandelion.com", text: $link)
                        .onChange(of: link) {
                            link = link.replacingOccurrences(of: "^(http|https)://", with: "", options: .regularExpression)
                        }

                    if useAPIKey {
                        onboardingSecureField(icon: "key", placeholder: "API Key", text: $apiKey)
                            .transition(.blurReplace)
                    } else {
                        onboardingField(icon: "person", placeholder: "Username", text: $username)
                            .transition(.blurReplace)
                        onboardingSecureField(icon: "lock", placeholder: "Password", text: $password)
                            .transition(.blurReplace)
                    }

                    HStack {
                        Image(systemName: "key")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text("Use API Key")
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: $useAPIKey)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: useAPIKey) {
                        if useAPIKey {
                            username = ""
                            password = ""
                        } else {
                            apiKey = ""
                        }
                    }

                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text("Enable SSL")
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: $isSSLEnabled)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 24)

                Link(destination: KMCore.userGuideURL) {
                    Label("User Guide", systemImage: "book")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func onboardingField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func onboardingSecureField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            SecureField(placeholder, text: text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func connect() {
        KMCore.saveNewDashboardConfigurations(
            dashboardLink: link,
            dashboardUsername: username,
            dashboardPassword: password,
            dashboardSSLEnabled: isSSLEnabled,
            apiKey: apiKey
        )
        state.loadDashboard()
        withAnimation(.smooth(duration: 0.5)) {
            isShowingOnboarding = false
        }
    }
}

// MARK: - Feature Page

private struct OnboardingFeaturePage: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    @State private var iconAppeared = false
    @State private var titleAppeared = false
    @State private var descAppeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(iconColor.gradient)
                .symbolRenderingMode(.hierarchical)
                .iconBounce(iconAppeared)
                .scaleEffect(iconAppeared ? 1 : 0.3)
                .opacity(iconAppeared ? 1 : 0)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: titleAppeared ? 0 : 20)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(descAppeared ? 1 : 0)
                    .offset(y: descAppeared ? 0 : 30)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                iconAppeared = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                titleAppeared = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
                descAppeared = true
            }
        }
    }
}

// MARK: - Page Dots

private struct OnboardingPageDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 24 : 8, height: 8)
            }
        }
        .animation(.spring(duration: 0.3), value: current)
    }
}
