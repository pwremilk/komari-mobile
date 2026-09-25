//
//  LoadAlertsView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 3/3/26.
//

import SwiftUI

private enum LoadAlertMetric: String, CaseIterable {
    case cpu = "cpu"
    case ram = "ram"
    case disk = "disk"
    case netIn = "net_in"
    case netOut = "net_out"

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .ram: "RAM"
        case .disk: "Disk"
        case .netIn: "Net In"
        case .netOut: "Net Out"
        }
    }

    var unit: String {
        switch self {
        case .cpu, .ram, .disk: "%"
        case .netIn, .netOut: "Mbps"
        }
    }
}

struct LoadAlertsView: View {
    @EnvironmentObject private var state: KMState

    @State private var alerts: [LoadAlert] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var isShowAddSheet = false
    @State private var alertToEdit: LoadAlert?
    @State private var alertToDelete: LoadAlert?
    @State private var isShowDeleteAlert = false

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
                        Task { await loadAlerts() }
                    }
                }
            } else if alerts.isEmpty {
                ContentUnavailableView {
                    Label("No Load Alerts", systemImage: "bell")
                } description: {
                    Text("Add a load alert to monitor server resource usage.")
                } actions: {
                    Button("Add Alert") {
                        isShowAddSheet = true
                    }
                }
            } else {
                alertList
            }
        }
        .navigationTitle("Load Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowAddSheet) {
            LoadAlertFormView(nodes: state.nodes) { name, metric, threshold, ratio, clients, interval in
                try await AdminHandler.addLoadAlert(
                    name: name, metric: metric, threshold: threshold,
                    ratio: ratio, clients: clients, interval: interval
                )
                await loadAlerts()
            }
        }
        .sheet(item: $alertToEdit) { alert in
            LoadAlertFormView(nodes: state.nodes, existingAlert: alert) { name, metric, threshold, ratio, clients, interval in
                guard let id = alert.id else { return }
                try await AdminHandler.editLoadAlert(
                    id: id, name: name, metric: metric, threshold: threshold,
                    ratio: ratio, clients: clients, interval: interval
                )
                await loadAlerts()
            }
        }
        .alert("Delete Alert", isPresented: $isShowDeleteAlert, presenting: alertToDelete) { alert in
            Button("Delete", role: .destructive) {
                guard let id = alert.id else { return }
                Task {
                    try? await AdminHandler.deleteLoadAlerts(ids: [id])
                    await loadAlerts()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { alert in
            Text("Are you sure you want to delete \"\(alert.displayName)\"?")
        }
        .task { await loadAlerts() }
    }

    private var alertList: some View {
        List {
            ForEach(alerts) { alert in
                LoadAlertRow(alert: alert, nodes: state.nodes)
                    .contextMenu {
                        Button {
                            alertToEdit = alert
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            alertToDelete = alert
                            isShowDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            alertToEdit = alert
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            alertToDelete = alert
                            isShowDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func loadAlerts() async {
        do {
            let fetched = try await AdminHandler.getLoadAlerts()
            withAnimation {
                alerts = fetched.sorted { ($0.id ?? 0) > ($1.id ?? 0) }
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

// MARK: - Alert Row

private struct LoadAlertRow: View {
    let alert: LoadAlert
    let nodes: [NodeData]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(alert.displayName)
                    .font(.headline)

                Spacer()

                Text(alert.displayMetric)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(metricColor.opacity(0.15))
                    .foregroundStyle(metricColor)
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                if let threshold = alert.threshold {
                    HStack(spacing: 2) {
                        Image(systemName: "gauge.high")
                        Text("\(threshold, specifier: "%.1f")\(metricUnit)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let ratio = alert.ratio {
                    HStack(spacing: 2) {
                        Image(systemName: "percent")
                        Text("\(ratio, specifier: "%.1f")")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let interval = alert.interval {
                    HStack(spacing: 2) {
                        Image(systemName: "timer")
                        Text("\(interval) min")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let clients = alert.clients {
                    HStack(spacing: 2) {
                        Image(systemName: "server.rack")
                        Text(serverSummary(clients))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var metricColor: Color {
        switch alert.metric?.lowercased() {
        case "cpu": .orange
        case "ram": .blue
        case "disk": .purple
        case "net_in": .green
        case "net_out": .teal
        default: .secondary
        }
    }

    private var metricUnit: String {
        switch alert.metric?.lowercased() {
        case "cpu", "ram", "disk": "%"
        case "net_in", "net_out": " Mbps"
        default: ""
        }
    }

    private func serverSummary(_ uuids: [String]) -> String {
        let names = uuids.compactMap { uuid in
            nodes.first(where: { $0.uuid == uuid })?.name
        }
        if names.count == uuids.count {
            return names.count <= 2 ? names.joined(separator: ", ") : "\(names.count) servers"
        } else {
            return "\(uuids.count) servers"
        }
    }
}

// MARK: - Add / Edit Form

private struct LoadAlertFormView: View {
    @Environment(\.dismiss) private var dismiss

    let nodes: [NodeData]
    let existingAlert: LoadAlert?
    let onSave: (String, String, Double, Double, [String], Int) async throws -> Void

    @State private var name: String = ""
    @State private var metric: LoadAlertMetric = .cpu
    @State private var threshold: String = "80"
    @State private var ratio: String = "0.8"
    @State private var interval: String = "15"
    @State private var selectedClients: Set<String> = []

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(nodes: [NodeData], existingAlert: LoadAlert? = nil, onSave: @escaping (String, String, Double, Double, [String], Int) async throws -> Void) {
        self.nodes = nodes
        self.existingAlert = existingAlert
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section("Options") {
                    Picker("Metric", selection: $metric) {
                        ForEach(LoadAlertMetric.allCases, id: \.self) { m in
                            Text(m.title).tag(m)
                        }
                    }

                    LabeledContent {
                        TextField(metric.unit, text: $threshold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("Threshold")
                    }
                    
                    LabeledContent {
                        TextField("0-1", text: $ratio)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("Ratio")
                    }
                    
                    LabeledContent {
                        TextField("Minutes", text: $interval)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("Interval")
                    }
                }

                Section("Servers") {
                    if nodes.isEmpty {
                        Text("No servers available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(nodes) { node in
                            Button {
                                if selectedClients.contains(node.uuid) {
                                    selectedClients.remove(node.uuid)
                                } else {
                                    selectedClients.insert(node.uuid)
                                }
                            } label: {
                                HStack {
                                    Text(node.name.isEmpty ? node.uuid : node.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedClients.contains(node.uuid) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.accent)
                                    }
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(existingAlert != nil ? "Edit Alert" : "Add Alert")
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
            .onAppear { populateFromExisting() }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(threshold) ?? -1) >= 0 &&
        (Double(ratio) ?? -1) >= 0 && (Double(ratio) ?? 2) <= 1 &&
        (Int(interval) ?? 0) > 0 &&
        !selectedClients.isEmpty
    }

    private func populateFromExisting() {
        guard let alert = existingAlert else { return }
        name = alert.name ?? ""
        if let m = alert.metric, let lm = LoadAlertMetric(rawValue: m) {
            metric = lm
        }
        threshold = alert.threshold.map { String($0) } ?? "80"
        ratio = alert.ratio.map { String($0) } ?? "0.8"
        interval = alert.interval.map { String($0) } ?? "15"
        selectedClients = Set(alert.clients ?? [])
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let thresholdValue = Double(threshold) ?? 80
                let ratioValue = Double(ratio) ?? 0.8
                let intervalValue = Int(interval) ?? 15
                try await onSave(
                    name.trimmingCharacters(in: .whitespaces),
                    metric.rawValue,
                    thresholdValue,
                    ratioValue,
                    Array(selectedClients),
                    intervalValue
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
