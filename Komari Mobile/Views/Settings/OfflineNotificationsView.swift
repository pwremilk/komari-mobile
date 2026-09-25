//
//  OfflineNotificationsView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 3/3/26.
//

import SwiftUI

struct OfflineNotificationsView: View {
    @EnvironmentObject private var state: KMState

    @State private var notifications: [OfflineNotification] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var nodeToEdit: NodeData?
    @State private var editEnabled = false
    @State private var editGracePeriod = "300"

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
                        Task { await loadNotifications() }
                    }
                }
            } else if state.nodes.isEmpty {
                ContentUnavailableView {
                    Label("No Servers", systemImage: "server.rack")
                } description: {
                    Text("No servers available to configure offline notifications.")
                }
            } else {
                nodeList
            }
        }
        .navigationTitle("Offline Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $nodeToEdit) { node in
            OfflineNotificationFormView(
                node: node,
                enabled: editEnabled,
                gracePeriod: editGracePeriod
            ) { enabled, gracePeriod in
                let entry: [String: Any] = [
                    "client": node.uuid,
                    "enable": enabled,
                    "cooldown": 3000,
                    "grace_period": gracePeriod
                ]
                try await AdminHandler.editOfflineNotifications(entries: [entry])
                await loadNotifications()
            }
        }
        .task { await loadNotifications() }
    }

    private var nodeList: some View {
        List {
            ForEach(state.nodes) { node in
                let notification = notifications.first { $0.client == node.uuid }
                OfflineNotificationRow(node: node, notification: notification)
                    .contextMenu {
                        Button {
                            prepareEdit(node: node, notification: notification)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            prepareEdit(node: node, notification: notification)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
            }
        }
    }

    private func prepareEdit(node: NodeData, notification: OfflineNotification?) {
        editEnabled = notification?.enable ?? false
        editGracePeriod = String(notification?.gracePeriod ?? 300)
        nodeToEdit = node
    }

    private func loadNotifications() async {
        do {
            let fetched = try await AdminHandler.getOfflineNotifications()
            withAnimation {
                notifications = fetched
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
}

// MARK: - Row

private struct OfflineNotificationRow: View {
    let node: NodeData
    let notification: OfflineNotification?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name.isEmpty ? node.uuid : node.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "timer")
                        Text("\(notification?.gracePeriod ?? 300)s")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let lastNotified = notification?.lastNotified {
                        HStack {
                            Image(systemName: "bell")
                            Text(formatLastNotified(lastNotified))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(isEnabled ? String(localized: "Enabled") : String(localized: "Disabled"))
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(isEnabled ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .foregroundStyle(isEnabled ? .green : .red)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var isEnabled: Bool {
        notification?.enable ?? false
    }

    private func formatLastNotified(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            if Calendar.current.component(.year, from: date) < 3 {
                return String(localized: "Never")
            }
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            if Calendar.current.component(.year, from: date) < 3 {
                return String(localized: "Never")
            }
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
        return dateString
    }
}

// MARK: - Form

private struct OfflineNotificationFormView: View {
    @Environment(\.dismiss) private var dismiss

    let node: NodeData
    @State var enabled: Bool
    @State var gracePeriod: String
    let onSave: (Bool, Int) async throws -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(node: NodeData, enabled: Bool, gracePeriod: String, onSave: @escaping (Bool, Int) async throws -> Void) {
        self.node = node
        self._enabled = State(initialValue: enabled)
        self._gracePeriod = State(initialValue: gracePeriod)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        Text(node.name.isEmpty ? node.uuid : node.name)
                            .font(.headline)
                    } label: {
                        Text("Server")
                    }
                }
                
                Section {
                    Toggle("Enabled", isOn: $enabled)
                }

                Section("Options") {
                    LabeledContent {
                        TextField("Seconds", text: $gracePeriod)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("Grace Period")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) {
                            dismiss()
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }
                    } else {
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        if #available(iOS 26.0, *) {
                            Button(role: .confirm) {
                                save()
                            } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .disabled(!isValid)
                        } else {
                            Button("Done") {
                                save()
                            }
                            .disabled(!isValid)
                        }
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        (Int(gracePeriod) ?? -1) >= 0
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let gracePeriodValue = Int(gracePeriod) ?? 300
                try await onSave(enabled, gracePeriodValue)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
