//
//  PingTasksView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 3/3/26.
//

import SwiftUI

private enum PingType: String, CaseIterable {
    case icmp = "icmp"
    case tcp = "tcp"
    case http = "http"

    var title: String {
        switch self {
        case .icmp: "ICMP"
        case .tcp: "TCP"
        case .http: "HTTP"
        }
    }

    var targetPlaceholder: String {
        switch self {
        case .icmp: "1.1.1.1"
        case .tcp: "1.1.1.1:443"
        case .http: "https://example.com"
        }
    }
}

struct PingTasksView: View {
    @EnvironmentObject private var state: KMState

    @State private var tasks: [PingTask] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var isShowAddSheet = false
    @State private var taskToEdit: PingTask?
    @State private var taskToDelete: PingTask?
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
                        Task { await loadTasks() }
                    }
                }
            } else if tasks.isEmpty {
                ContentUnavailableView {
                    Label("No Ping Tasks", systemImage: "network")
                } description: {
                    Text("Add a ping task to monitor network connectivity.")
                } actions: {
                    Button("Add Task") {
                        isShowAddSheet = true
                    }
                }
            } else {
                taskList
            }
        }
        .navigationTitle("Ping Tasks")
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
            PingTaskFormView(nodes: state.nodes) { name, type, target, clients, interval in
                try await AdminHandler.addPingTask(
                    name: name, type: type, target: target,
                    clients: clients, interval: interval
                )
                await loadTasks()
            }
        }
        .sheet(item: $taskToEdit) { task in
            PingTaskFormView(nodes: state.nodes, existingTask: task) { name, type, target, clients, interval in
                guard let id = task.id else { return }
                try await AdminHandler.editPingTask(
                    id: id, name: name, type: type, target: target,
                    clients: clients, interval: interval
                )
                await loadTasks()
            }
        }
        .alert("Delete Task", isPresented: $isShowDeleteAlert, presenting: taskToDelete) { task in
            Button("Delete", role: .destructive) {
                guard let id = task.id else { return }
                Task {
                    try? await AdminHandler.deletePingTasks(ids: [id])
                    await loadTasks()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { task in
            Text("Are you sure you want to delete \"\(task.displayName)\"?")
        }
        .task { await loadTasks() }
    }

    private var taskList: some View {
        List {
            ForEach(tasks) { task in
                PingTaskRow(task: task, nodes: state.nodes)
                    .contextMenu {
                        Button {
                            taskToEdit = task
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            taskToDelete = task
                            isShowDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            taskToDelete = task
                            isShowDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            taskToEdit = task
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        }
    }

    private func loadTasks() async {
        do {
            let fetched = try await AdminHandler.getPingTasks()
            withAnimation {
                tasks = fetched.sorted { ($0.id ?? 0) > ($1.id ?? 0) }
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

// MARK: - Task Row

private struct PingTaskRow: View {
    let task: PingTask
    let nodes: [NodeData]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.displayName)
                    .font(.headline)

                Spacer()

                Text(task.displayType)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())
            }

            if let target = task.target, !target.isEmpty {
                Text(target)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                if let interval = task.interval {
                    HStack {
                        Image(systemName: "timer")
                        Text("\(interval)s")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let clients = task.clients {
                    HStack {
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

    private var typeColor: Color {
        switch task.type?.lowercased() {
        case "icmp": .blue
        case "tcp": .orange
        case "http": .green
        default: .secondary
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

private struct PingTaskFormView: View {
    @Environment(\.dismiss) private var dismiss

    let nodes: [NodeData]
    let existingTask: PingTask?
    let onSave: (String, String, String, [String], Int) async throws -> Void

    @State private var name: String = ""
    @State private var pingType: PingType = .icmp
    @State private var target: String = ""
    @State private var interval: String = "60"
    @State private var selectedClients: Set<String> = []

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(nodes: [NodeData], existingTask: PingTask? = nil, onSave: @escaping (String, String, String, [String], Int) async throws -> Void) {
        self.nodes = nodes
        self.existingTask = existingTask
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
                    Picker("Type", selection: $pingType) {
                        ForEach(PingType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }

                    TextField(pingType.targetPlaceholder, text: $target)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(pingType == .http ? .URL : .default)

                    TextField("Interval (seconds)", text: $interval)
                        .keyboardType(.numberPad)
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
            .navigationTitle(existingTask != nil ? "Edit Task" : "Add Task")
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
        !target.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(interval) ?? 0) > 0 &&
        !selectedClients.isEmpty
    }

    private func populateFromExisting() {
        guard let task = existingTask else { return }
        name = task.name ?? ""
        if let type = task.type, let pt = PingType(rawValue: type.lowercased()) {
            pingType = pt
        }
        target = task.target ?? ""
        interval = task.interval.map { String($0) } ?? "60"
        selectedClients = Set(task.clients ?? [])
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let intervalValue = Int(interval) ?? 60
                try await onSave(
                    name.trimmingCharacters(in: .whitespaces),
                    pingType.rawValue,
                    target.trimmingCharacters(in: .whitespaces),
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
