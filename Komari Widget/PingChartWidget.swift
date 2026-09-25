//
//  PingChartWidget.swift
//  Komari Widget
//
//  Created by Junhui Lou on 2/19/26.
//

import WidgetKit
import SwiftUI
import Charts

// MARK: - Data Point

struct PingWidgetPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let taskId: Int
    let taskName: String
}

// MARK: - Entry

struct PingChartEntry: TimelineEntry {
    let date: Date
    let serverName: String
    let serverRegion: String
    let tasks: [PingTaskInfo]
    let chartPoints: [PingWidgetPoint]
    let isConfigured: Bool
    let errorMessage: String?
}

// MARK: - Provider

struct PingChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PingChartEntry {
        PingChartEntry(date: .now, serverName: "Server", serverRegion: "🌍", tasks: [], chartPoints: [], isConfigured: true, errorMessage: nil)
    }

    func snapshot(for configuration: SelectPingIntent, in context: Context) async -> PingChartEntry {
        PingChartEntry(date: .now, serverName: "Server", serverRegion: "🌍", tasks: [], chartPoints: [], isConfigured: true, errorMessage: nil)
    }

    func timeline(for configuration: SelectPingIntent, in context: Context) async -> Timeline<PingChartEntry> {
        guard WidgetKMCore.isConfigured else {
            let entry = PingChartEntry(date: .now, serverName: "", serverRegion: "", tasks: [], chartPoints: [], isConfigured: false, errorMessage: nil)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        }

        do {
            try await WidgetDataProvider.ensureAuth()
            let nodes = try await WidgetDataProvider.getNodes()

            let serverID = configuration.server?.id ?? nodes.values.sorted(by: { $0.weight < $1.weight }).first?.uuid
            guard let id = serverID, let node = nodes[id] else {
                let entry = PingChartEntry(date: .now, serverName: "", serverRegion: "", tasks: [], chartPoints: [], isConfigured: true, errorMessage: "Server not found")
                return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
            }

            let pingData = try await WidgetDataProvider.getPingRecords(uuid: id, hours: 1)
            let allTasks = pingData.tasks ?? []
            let records = pingData.records ?? []

            let selectedTaskId = configuration.task.flatMap { Int($0.id) }
            let tasks: [PingTaskInfo]
            if let selectedId = selectedTaskId {
                tasks = allTasks.filter { $0.id == selectedId }
            } else {
                tasks = allTasks
            }
            let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.name) })

            let points: [PingWidgetPoint] = records.compactMap { record in
                guard let timeStr = record.time,
                      let date = WidgetDateParser.parseDate(timeStr),
                      let value = record.value,
                      let taskId = record.taskId,
                      let taskName = taskMap[taskId] else { return nil }
                return PingWidgetPoint(date: date, value: value, taskId: taskId, taskName: taskName)
            }

            let downsampled = downsampleByTask(points, maxPerTask: 30)

            let entry = PingChartEntry(date: .now, serverName: node.name, serverRegion: node.region, tasks: tasks, chartPoints: downsampled, isConfigured: true, errorMessage: nil)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        } catch {
            let entry = PingChartEntry(date: .now, serverName: "", serverRegion: "", tasks: [], chartPoints: [], isConfigured: true, errorMessage: error.localizedDescription)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        }
    }

    private func downsampleByTask(_ points: [PingWidgetPoint], maxPerTask: Int) -> [PingWidgetPoint] {
        let grouped = Dictionary(grouping: points, by: { $0.taskId })
        return grouped.values.flatMap { taskPoints in
            guard taskPoints.count > maxPerTask else { return taskPoints }
            let stride = max(1, taskPoints.count / maxPerTask)
            return Swift.stride(from: 0, to: taskPoints.count, by: stride).map { taskPoints[$0] }
        }
    }
}

// MARK: - Task Colors

private let taskColors: [Color] = [.blue, .orange, .green, .purple, .red, .cyan]

private func colorForTask(_ index: Int) -> Color {
    taskColors[index % taskColors.count]
}

// MARK: - Views

struct PingChartSmallView: View {
    let entry: PingChartEntry

    var body: some View {
        if !entry.isConfigured {
            VStack {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Configure in Komari App")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage = entry.errorMessage {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } else if let firstTask = entry.tasks.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(entry.serverRegion)
                        .font(.caption2)
                    Text(entry.serverName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Text(firstTask.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let latest = firstTask.latest {
                        VStack(alignment: .leading) {
                            Text("Ping")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0fms", latest))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    if let loss = firstTask.loss {
                        VStack(alignment: .leading) {
                            Text("Loss")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f%%", loss))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(loss > 5 ? .red : .primary)
                        }
                    }
                }

                let taskPoints = entry.chartPoints.filter { $0.taskId == firstTask.id }
                if !taskPoints.isEmpty {
                    Chart(taskPoints) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Ping", point.value)
                        )
                        .foregroundStyle(.blue)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                }
            }
        } else {
            VStack {
                HStack(spacing: 4) {
                    Text(entry.serverRegion)
                        .font(.caption2)
                    Text(entry.serverName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                Text("No ping tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PingChartMediumView: View {
    let entry: PingChartEntry

    var body: some View {
        if !entry.isConfigured {
            HStack {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Configure Komari in the app to use widgets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage = entry.errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } else {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(entry.serverRegion)
                            .font(.caption)
                        Text(entry.serverName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }

                    let displayTasks = Array(entry.tasks.prefix(2))
                    ForEach(Array(displayTasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(colorForTask(index))
                                .frame(width: 3, height: 16)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(task.name)
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    if let latest = task.latest {
                                        Text(String(format: "%.0fms", latest))
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                    }
                                    if let loss = task.loss {
                                        Text(String(format: "%.1f%%", loss))
                                            .font(.system(size: 8))
                                            .foregroundStyle(loss > 5 ? .red : .secondary)
                                    }
                                }
                            }
                        }
                    }

                    if entry.tasks.isEmpty {
                        Text("No ping tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .frame(width: 90)

                if !entry.chartPoints.isEmpty {
                    let displayTaskIDs = Set(entry.tasks.prefix(2).map { $0.id })
                    let filteredPoints = entry.chartPoints.filter { displayTaskIDs.contains($0.taskId) }

                    Chart(filteredPoints) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Ping", point.value)
                        )
                        .foregroundStyle(by: .value("Task", point.taskName))
                    }
                    .chartForegroundStyleScale(range: entry.tasks.prefix(2).enumerated().map { colorForTask($0.offset) })
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .minute, count: 15)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(String(format: "%.0f", v))
                                        .font(.system(size: 8))
                                }
                            }
                        }
                    }
                    .chartLegend(.hidden)
                } else {
                    Spacer()
                    Text("No data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Widget

struct PingChartWidget: Widget {
    let kind: String = "PingChartWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectPingIntent.self, provider: PingChartProvider()) { entry in
            PingChartSmallOrMediumView(entry: entry)
                .widgetBG()
        }
        .configurationDisplayName("Ping Chart")
        .description("Monitor server ping latency.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct PingChartSmallOrMediumView: View {
    let entry: PingChartEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            PingChartSmallView(entry: entry)
        default:
            PingChartMediumView(entry: entry)
        }
    }
}
