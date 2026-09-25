//
//  GeneralNotificationsView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 3/7/26.
//

import SwiftUI

struct GeneralNotificationsView: View {
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var expireEnabled = false
    @State private var expireLeadDays: String = "7"
    @State private var loginNotification = false
    @State private var trafficLimitPercentage: String = "80"

    @State private var isSaving = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") {
                        Task { await loadSettings() }
                    }
                }
            } else {
                settingsForm
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSettings() }
    }

    private var settingsForm: some View {
        Form {
            Section {
                Toggle("Enable", isOn: $expireEnabled)
                    .onChange(of: expireEnabled) { newValue in
                        Task {
                            await updateSetting(["expire_notification_enabled": newValue])
                        }
                    }

                LabeledContent {
                    TextField("Days", text: $expireLeadDays)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { saveLeadDays() }
                } label: {
                    Text("Lead Days")
                }
            } header: {
                Text("Expiration Notification")
            } footer: {
                Text("Notify when a server's billing is about to expire. Lead days controls how many days before expiration to send the notification.")
            }

            Section {
                Toggle("Login Notification", isOn: $loginNotification)
                    .onChange(of: loginNotification) { newValue in
                        Task {
                            await updateSetting(["login_notification": newValue])
                        }
                    }
            } footer: {
                Text("Notify when someone logs in to the admin dashboard.")
            }

            Section {
                LabeledContent {
                    TextField("%", text: $trafficLimitPercentage)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { saveTrafficPercentage() }
                } label: {
                    Text("Threshold")
                }
            } header: {
                Text("Traffic Alert")
            } footer: {
                Text("Notify when a server's traffic usage reaches this percentage of its limit.")
            }

            Section {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        saveLeadDays()
                        saveTrafficPercentage()
                    }
                }
            }
        }
    }

    private func loadSettings() async {
        do {
            let settings = try await AdminHandler.getSettings()
            withAnimation {
                expireEnabled = settings.expireNotificationEnabled ?? false
                expireLeadDays = String(settings.expireNotificationLeadDays ?? 7)
                loginNotification = settings.loginNotification ?? false
                trafficLimitPercentage = String(settings.trafficLimitPercentage ?? 80)
                isLoading = false
                errorMessage = nil
            }
        } catch {
            withAnimation {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func saveLeadDays() {
        guard let days = Int(expireLeadDays), days >= 0 else { return }
        Task {
            await updateSetting(["expire_notification_lead_days": days])
        }
    }

    private func saveTrafficPercentage() {
        guard let pct = Double(trafficLimitPercentage), pct >= 0 else { return }
        Task {
            await updateSetting(["traffic_limit_percentage": pct])
        }
    }

    private func updateSetting(_ changes: [String: Any]) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await AdminHandler.updateSettings(changes: changes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
