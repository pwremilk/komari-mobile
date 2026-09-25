//
//  ServerStatusWidget.swift
//  Komari Widget
//
//  Created by Junhui Lou on 2/19/26.
//

import WidgetKit
import SwiftUI

// MARK: - Entry

struct ServerStatusEntry: TimelineEntry {
    let date: Date
    let node: NodeData?
    let status: NodeLiveStatus?
    let isOnline: Bool
    let isConfigured: Bool
    let errorMessage: String?
}

// MARK: - Provider

struct ServerStatusProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ServerStatusEntry {
        ServerStatusEntry(date: .now, node: nil, status: nil, isOnline: true, isConfigured: true, errorMessage: nil)
    }

    func snapshot(for configuration: SelectServerIntent, in context: Context) async -> ServerStatusEntry {
        ServerStatusEntry(date: .now, node: nil, status: nil, isOnline: true, isConfigured: true, errorMessage: nil)
    }

    func timeline(for configuration: SelectServerIntent, in context: Context) async -> Timeline<ServerStatusEntry> {
        guard WidgetKMCore.isConfigured else {
            let entry = ServerStatusEntry(date: .now, node: nil, status: nil, isOnline: false, isConfigured: false, errorMessage: nil)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        }

        do {
            try await WidgetDataProvider.ensureAuth()
            let nodes = try await WidgetDataProvider.getNodes()
            let statuses = try await WidgetDataProvider.getNodesLatestStatus()

            let serverID = configuration.server?.id ?? nodes.values.sorted(by: { $0.weight < $1.weight }).first?.uuid
            guard let id = serverID, let node = nodes[id] else {
                let entry = ServerStatusEntry(date: .now, node: nil, status: nil, isOnline: false, isConfigured: true, errorMessage: "Server not found")
                return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
            }

            let status = statuses[id]
            let entry = ServerStatusEntry(date: .now, node: node, status: status, isOnline: status?.online ?? false, isConfigured: true, errorMessage: nil)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        } catch {
            let entry = ServerStatusEntry(date: .now, node: nil, status: nil, isOnline: false, isConfigured: true, errorMessage: error.localizedDescription)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        }
    }
}

// MARK: - Threshold Color

private func thresholdColor(for value: Double) -> Color {
    let clamped = min(max(value, 0), 100)
    if clamped >= 80 { return .red }
    if clamped >= 60 { return .orange }
    return .green
}

// MARK: - Usage Bar

struct WidgetUsageBar: View {
    let label: String
    let value: Double

    private var clampedValue: Double { min(max(value, 0), 100) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(clampedValue))%")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.systemGray3))
                    Capsule()
                        .fill(thresholdColor(for: clampedValue))
                        .frame(width: max(0, geo.size.width * CGFloat(clampedValue / 100)))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Gauge Ring

struct WidgetGaugeRing: View {
    let label: String
    let value: Double
    
    private let lineWidth: CGFloat = 5
    private let size: CGFloat = 52
    
    private var clampedValue: Double { min(max(value, 0), 100) }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color(UIColor.systemGray3), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: clampedValue / 100)
                    .stroke(thresholdColor(for: clampedValue).gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: thresholdColor(for: clampedValue).opacity(0.3), radius: 3)
                    .animation(.easeOut(duration: 0.6), value: clampedValue)
                Text("\(Int(clampedValue))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: clampedValue))
            }
            .frame(width: size, height: size)
            
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Small View

struct ServerStatusSmallView: View {
    let entry: ServerStatusEntry

    var body: some View {
        if !entry.isConfigured {
            VStack(spacing: 6) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Configure in Komari App")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage = entry.errorMessage {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        } else if let node = entry.node {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(node.region)
                        .font(.caption)
                    Text(node.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Circle()
                        .fill(entry.isOnline ? Color.green : Color.red)
                        .frame(width: 5, height: 5)
                        .shadow(color: (entry.isOnline ? Color.green : Color.red).opacity(0.6), radius: 3)
                }
                .lineLimit(1)

                Spacer()
                
                if let status = entry.status {
                    let cpuValue = min(status.cpuUsage, 100)
                    let ramValue = status.memoryTotal > 0 ? Double(status.memoryUsed) / Double(status.memoryTotal) * 100 : 0
                    let diskValue = status.diskTotal > 0 ? Double(status.diskUsed) / Double(status.diskTotal) * 100 : 0

                    WidgetUsageBar(label: "CPU", value: cpuValue)
                    WidgetUsageBar(label: "RAM", value: ramValue)
                    WidgetUsageBar(label: "Disk", value: diskValue)
                } else {
                    Text("Unavailble")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        } else {
            ProgressView("Loading...")
        }
    }
}

// MARK: - Medium View

struct ServerStatusMediumView: View {
    let entry: ServerStatusEntry

    var body: some View {
        if !entry.isConfigured {
            HStack(spacing: 8) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Configure Komari in the app to use widgets")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage = entry.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } else if let node = entry.node {
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Text(node.region)
                            .font(.caption)
                        Text(node.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(entry.isOnline ? Color.green : Color.red)
                            .frame(width: 5, height: 5)
                            .shadow(color: (entry.isOnline ? Color.green : Color.red).opacity(0.6), radius: 3)

                        if entry.isOnline {
                            Text("Online")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Offline")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .lineLimit(1)
                
                Spacer()
                
                if let status = entry.status {
                    let cpuValue = min(status.cpuUsage, 100)
                    let ramValue = status.memoryTotal > 0 ? Double(status.memoryUsed) / Double(status.memoryTotal) * 100 : 0
                    let diskValue = status.diskTotal > 0 ? Double(status.diskUsed) / Double(status.diskTotal) * 100 : 0
                    
                    HStack {
                        Spacer()
                        WidgetGaugeRing(label: "CPU", value: cpuValue)
                        Spacer()
                        WidgetGaugeRing(label: "RAM", value: ramValue)
                        Spacer()
                        WidgetGaugeRing(label: "Disk", value: diskValue)
                        Spacer()
                    }
                } else {
                    Text("Unavailble")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        } else {
            ProgressView("Loading...")
        }
    }
}

// MARK: - Widget

struct ServerStatusWidget: Widget {
    let kind: String = "ServerStatusWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectServerIntent.self, provider: ServerStatusProvider()) { entry in
            ServerStatusSmallOrMediumView(entry: entry)
                .widgetBG()
        }
        .configurationDisplayName("Server Status")
        .description("Monitor server status at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ServerStatusSmallOrMediumView: View {
    let entry: ServerStatusEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            ServerStatusSmallView(entry: entry)
        default:
            ServerStatusMediumView(entry: entry)
        }
    }
}
