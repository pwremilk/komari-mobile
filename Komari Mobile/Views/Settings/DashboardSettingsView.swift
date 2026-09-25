//
//  DashboardSettingsView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI

struct DashboardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: KMState
    @State private var link: String = KMCore.getKomariDashboardLink()
    @State private var username: String = KMCore.getKomariDashboardUsername()
    @State private var password: String = KMCore.getKomariDashboardPassword()
    @State private var apiKey: String = KMCore.getKomariAPIKey()
    @State private var isSSLEnabled: Bool = KMCore.getIsKomariDashboardSSLEnabled()
    @State private var useAPIKey: Bool = !KMCore.getKomariAPIKey().isEmpty
    @State private var testResult: String = ""
    @State private var isTesting: Bool = false

    var body: some View {
        Form {
            Section {
                TextField("Dashboard Link", text: $link)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: link) { _ in
                        link = link.replacingOccurrences(of: "^(http|https)://", with: "", options: .regularExpression)
                    }
            } header: {
                Text("Dashboard Info")
            } footer: {
                Text("Dashboard Link Example: komari.hidandelion.com")
            }

            Section("Authentication") {
                Toggle("Use API Key", isOn: $useAPIKey)
                    .onChange(of: useAPIKey) { _ in
                        if useAPIKey {
                            username = ""
                            password = ""
                        } else {
                            apiKey = ""
                        }
                    }

                if useAPIKey {
                    SecureField("API Key", text: $apiKey)
                } else {
                    TextField("Username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                }
            }

            Section {
                Toggle("Enable SSL", isOn: $isSSLEnabled)
            }

            Section {
                Button("Save & Apply") {
                    KMCore.saveNewDashboardConfigurations(
                        dashboardLink: link,
                        dashboardUsername: username,
                        dashboardPassword: password,
                        dashboardSSLEnabled: isSSLEnabled,
                        apiKey: apiKey
                    )
                    state.loadDashboard()
                    dismiss()
                }
            }
            
            Section {
                Button("Test Connection") {
                    testConnection()
                }
                .disabled(isTesting)
            } footer: {
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(testResult.contains("Success") ? .green : .red)
                }
            }
        }
        .navigationTitle("Dashboard Settings")
    }

    private func testConnection() {
        isTesting = true
        testResult = ""
        // Temporarily save to test
        KMCore.saveNewDashboardConfigurations(
            dashboardLink: link,
            dashboardUsername: username,
            dashboardPassword: password,
            dashboardSSLEnabled: isSSLEnabled,
            apiKey: apiKey
        )
        Task {
            do {
                if !username.isEmpty && !password.isEmpty {
                    try await AuthHandler.login(username: username, password: password)
                }
                _ = try await AuthHandler.getMe()
                testResult = "Success! Connection verified."
            } catch {
                testResult = "Error: \(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}
