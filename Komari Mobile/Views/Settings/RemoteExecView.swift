//
//  RemoteExecView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 3/7/26.
//

import SwiftUI

struct RemoteExecView: View {
    @EnvironmentObject private var state

    @State private var command = ""
    @State private var selectedClients: Set<String> = []
    @State private var isExecuting = false
    @State private var isPolling = false
    @State private var results: [ExecResult] = []
    @State private var errorMessage: String?
    @State private var taskId: String?
    @State private var pollTask: Task<Void, Never>?

    private var isValid: Bool {
        !command.trimmingCharacters(in: .whitespaces).isEmpty && !selectedClients.isEmpty
    }

    var body: some View {
        List {
            commandSection
            serverSection

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if !results.isEmpty {
                resultsSection
            }
        }
        .navigationTitle("Remote Exec")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isExecuting || isPolling {
                    ProgressView()
                } else {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) {
                            executeCommand()
                        } label: {
                            Label("Execute", systemImage: "play.fill")
                        }
                        .disabled(!isValid)
                    }
                    else {
                        Button("Execute") {
                            executeCommand()
                        }
                        .disabled(!isValid)
                    }
                }
            }
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    // MARK: - Sections

    private var commandSection: some View {
        Section("Command") {
            TextEditor(text: $command)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .disabled(isExecuting || isPolling)
        }
    }

    private var serverSection: some View {
        Section("Servers") {
            if state.nodes.isEmpty {
                Text("No servers available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(state.nodes) { node in
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
                    .disabled(isExecuting || isPolling)
                }

                if state.nodes.count > 1 {
                    Button(selectedClients.count == state.nodes.count ? "Deselect All" : "Select All") {
                        if selectedClients.count == state.nodes.count {
                            selectedClients.removeAll()
                        } else {
                            selectedClients = Set(state.nodes.map(\.uuid))
                        }
                    }
                    .disabled(isExecuting || isPolling)
                }
            }
        }
    }

    private var resultsSection: some View {
        Section("Results") {
            ForEach(results) { result in
                ExecResultRow(result: result, nodes: state.nodes)
            }
        }
    }

    // MARK: - Execution

    private func executeCommand() {
        isExecuting = true
        errorMessage = nil
        results = []
        taskId = nil
        pollTask?.cancel()

        Task {
            do {
                let taskData = try await AdminHandler.execTask(
                    command: command.trimmingCharacters(in: .whitespaces),
                    clients: Array(selectedClients)
                )
                taskId = taskData.taskId
                isExecuting = false

                if let id = taskData.taskId {
                    startPolling(taskId: id)
                }
            } catch {
                errorMessage = error.localizedDescription
                isExecuting = false
            }
        }
    }

    private func startPolling(taskId: String) {
        isPolling = true

        pollTask = Task {
            let startTime = Date()
            let timeout: TimeInterval = 60

            while !Task.isCancelled {
                do {
                    let fetched = try await AdminHandler.getTaskResult(taskId: taskId)
                    withAnimation {
                        results = fetched
                    }

                    let allFinished = fetched.allSatisfy { $0.finishedAt != nil }
                    if allFinished {
                        withAnimation { isPolling = false }
                        return
                    }
                } catch {
                    withAnimation {
                        errorMessage = error.localizedDescription
                        isPolling = false
                    }
                    return
                }

                if Date().timeIntervalSince(startTime) >= timeout {
                    withAnimation {
                        results = results.map { r in
                            if r.finishedAt == nil {
                                return ExecResult(
                                    taskId: r.taskId,
                                    client: r.client,
                                    clientInfo: r.clientInfo,
                                    result: "Execution timeout",
                                    exitCode: -1,
                                    finishedAt: ISO8601DateFormatter().string(from: .now),
                                    createdAt: r.createdAt
                                )
                            }
                            return r
                        }
                        isPolling = false
                    }
                    return
                }

                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}

// MARK: - Result Row

private struct ExecResultRow: View {
    let result: ExecResult
    let nodes: [NodeData]

    private var nodeName: String {
        if let info = result.clientInfo, let name = info.name, !name.isEmpty {
            return name
        }
        if let client = result.client,
           let node = nodes.first(where: { $0.uuid == client }) {
            return node.name.isEmpty ? client : node.name
        }
        return result.client ?? "Unknown"
    }

    private var status: ExecStatus {
        if result.finishedAt == nil {
            return .running
        }
        if result.exitCode == -1 {
            return .timeout
        }
        if result.exitCode == 0 {
            return .success
        }
        return .failed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(nodeName)
                    .font(.headline)

                Spacer()

                statusBadge
            }

            if let exitCode = result.exitCode, result.finishedAt != nil {
                HStack(spacing: 2) {
                    Text("Exit code:")
                        .foregroundStyle(.secondary)
                    Text("\(exitCode)")
                        .monospaced()
                }
                .font(.caption)
            }

            if let output = result.result, !output.isEmpty {
                Text(output)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.label)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(status.color.opacity(0.15))
        .foregroundStyle(status.color)
        .clipShape(Capsule())
    }
}

// MARK: - Status

private enum ExecStatus {
    case running, success, failed, timeout

    var label: String {
        switch self {
        case .running: "Running"
        case .success: "Success"
        case .failed: "Failed"
        case .timeout: "Timeout"
        }
    }

    var icon: String {
        switch self {
        case .running: "progress.indicator"
        case .success: "checkmark"
        case .failed: "exclamationmark.triangle"
        case .timeout: "clock.badge.exclamationmark"
        }
    }

    var color: Color {
        switch self {
        case .running: .blue
        case .success: .green
        case .failed: .red
        case .timeout: .orange
        }
    }
}
