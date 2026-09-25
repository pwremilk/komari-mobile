//
//  SettingsView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: KMState

    var body: some View {
        NavigationStack(path: kmBinding(for: .pathSettings, on: state)) {
            Form {
                Section("App Settings") {
                    NavigationLink(value: "dashboard-settings") {
                        TextWithColorfulIcon(titleKey: "Dashboard Settings", systemName: "gearshape.fill", color: .blue)
                    }
                }

                Section("Notifications") {
                    NavigationLink(value: "offline-notifications") {
                        TextWithColorfulIcon(titleKey: "Offline Notifications", systemName: "wifi.slash", color: .blue)
                    }
                    NavigationLink(value: "load-alerts") {
                        TextWithColorfulIcon(titleKey: "Load Alerts", systemName: "exclamationmark.triangle", color: .orange)
                    }
                    NavigationLink(value: "general-notifications") {
                        TextWithColorfulIcon(titleKey: "General Notifications", systemName: "bell", color: .red)
                    }
                }

                Section("Administration") {
                    NavigationLink(value: "ping-tasks") {
                        TextWithColorfulIcon(titleKey: "Ping Tasks", systemName: "network", color: .blue)
                    }
                    NavigationLink(value: "remote-exec") {
                        TextWithColorfulIcon(titleKey: "Remote Exec", systemName: "terminal", color: .black)
                    }
                    NavigationLink(value: "sessions") {
                        TextWithColorfulIcon(titleKey: "Sessions", systemName: "person.2", color: .teal)
                    }
                    NavigationLink(value: "account") {
                        TextWithColorfulIcon(titleKey: "Account", systemName: "person.crop.circle", color: .green)
                    }
                    NavigationLink(value: "logs") {
                        TextWithColorfulIcon(titleKey: "Logs", systemName: "doc.text", color: .gray)
                    }
                }

                Section("About") {
                    Link(destination: KMCore.userGuideURL) {
                        TextWithColorfulIcon(titleKey: "User Guide", systemName: "book", color: .blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: "acknowledgments") {
                        TextWithColorfulIcon(titleKey: "Acknowledgments", systemName: "heart", color: .pink)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: String.self) { target in
                switch(target) {
                case "dashboard-settings":
                    DashboardSettingsView()
                case "ping-tasks":
                    PingTasksView()
                case "load-alerts":
                    LoadAlertsView()
                case "offline-notifications":
                    OfflineNotificationsView()
                case "general-notifications":
                    GeneralNotificationsView()
                case "remote-exec":
                    RemoteExecView()
                case "sessions":
                    SessionsView()
                case "account":
                    AccountView()
                case "logs":
                    LogsView()
                case "acknowledgments":
                    AcknowledgmentView()
                default:
                    EmptyView()
                }
            }
        }
    }
}
