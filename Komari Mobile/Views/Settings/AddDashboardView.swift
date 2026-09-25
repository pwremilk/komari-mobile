//
//  AddDashboardView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI

struct AddDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state
    @Binding var isShowingOnboarding: Bool
    @State private var link: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var apiKey: String = ""
    @State private var isSSLEnabled: Bool = true
    @State private var useAPIKey: Bool = false

    private var canSave: Bool {
        if link.isEmpty { return false }
        if useAPIKey {
            return !apiKey.isEmpty
        } else {
            return !username.isEmpty && !password.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Dashboard Link", text: $link)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: link) {
                            link = link.replacingOccurrences(of: "^(http|https)://", with: "", options: .regularExpression)
                        }
                } header: {
                    Text("Dashboard Info")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Dashboard Link Example: komari.hidandelion.com")
                    }
                }

                Section("Authentication") {
                    Toggle("Use API Key", isOn: $useAPIKey)
                        .onChange(of: useAPIKey) {
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
                    Link("User Guide", destination: KMCore.userGuideURL)
                }
            }
            .navigationTitle("Add Dashboard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        KMCore.saveNewDashboardConfigurations(
                            dashboardLink: link,
                            dashboardUsername: username,
                            dashboardPassword: password,
                            dashboardSSLEnabled: isSSLEnabled,
                            apiKey: apiKey
                        )
                        state.loadDashboard()
                        isShowingOnboarding = false
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
