//
//  LoadChartWidget.swift
//  Komari Widget
//
//  Created by Junhui Lou on 2/19/26.
//

import WidgetKit
import SwiftUI
import Charts

// MARK: - Data Point

struct WidgetChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Entry

struct LoadChartEntry: TimelineEntry {
    let date: Date
    let serverName: String
    let serverRegion: String
    let indicator: LoadIndicator
    let dataPoints: [WidgetChartPoint]
    let currentValue: String
    let isConfigured: Bool
    let errorMessage: String?
}

// MARK: - Provider

struct LoadChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LoadChartEntry {
        LoadChartEntry(date: .now, serverName: "Server", serverRegion: "🌍", indicator: .cpu, dataPoints: [], currentValue: "--", isConfigured: true, errorMessage: nil)
    }
    
    func snapshot(for configuration: SelectLoadChartIntent, in context: Context) async -> LoadChartEntry {
        LoadChartEntry(date: .now, serverName: "Server", serverRegion: "🌍", indicator: configuration.indicator, dataPoints: [], currentValue: "--", isConfigured: true, errorMessage: nil)
    }
    
    func timeline(for configuration: SelectLoadChartIntent, in context: Context) async -> Timeline<LoadChartEntry> {
        let indicator = configuration.indicator
        
        guard WidgetKMCore.isConfigured else {
            let entry = LoadChartEntry(date: .now, serverName: "", serverRegion: "", indicator: indicator, dataPoints: [], currentValue: "--", isConfigured: false, errorMessage: nil)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        }
        
        do {
            try await WidgetDataProvider.ensureAuth()
            let nodes = try await WidgetDataProvider.getNodes()
            
            let serverID = configuration.server?.id ?? nodes.values.sorted(by: { $0.weight < $1.weight }).first?.uuid
            guard let id = serverID, let node = nodes[id] else {
                let entry = LoadChartEntry(date: .now, serverName: "", serverRegion: "", indicator: indicator, dataPoints: [], currentValue: "--", isConfigured: true, errorMessage: "Server not found")
                return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
            }
            
            let records = try await WidgetDataProvider.getRecords(uuid: id, hours: 4)
            let points = extractPoints(from: records, indicator: indicator, memTotal: node.memoryTotal, diskTotal: node.diskTotal)
            let downsampled = downsample(points, maxCount: 60)
            
            let currentValue = formatCurrentValue(points.last?.value, indicator: indicator)
            
            let entry = LoadChartEntry(date: .now, serverName: node.name, serverRegion: node.region, indicator: indicator, dataPoints: downsampled, currentValue: currentValue, isConfigured: true, errorMessage: nil)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        } catch {
            let entry = LoadChartEntry(date: .now, serverName: "", serverRegion: "", indicator: indicator, dataPoints: [], currentValue: "--", isConfigured: true, errorMessage: error.localizedDescription)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        }
    }
    
    private func extractPoints(from records: [NodeRecord], indicator: LoadIndicator, memTotal: Int64, diskTotal: Int64) -> [WidgetChartPoint] {
        records.compactMap { record in
            guard let timeStr = record.time, let date = WidgetDateParser.parseDate(timeStr) else { return nil }
            let value: Double?
            switch indicator {
            case .cpu:
                value = record.cpuUsage
            case .memory:
                if let used = record.memoryUsed, memTotal > 0 {
                    value = Double(used) / Double(memTotal) * 100
                } else {
                    value = nil
                }
            case .disk:
                if let used = record.diskUsed, diskTotal > 0 {
                    value = Double(used) / Double(diskTotal) * 100
                } else {
                    value = nil
                }
            case .networkIn:
                value = record.networkIn.map { Double($0) }
            case .networkOut:
                value = record.networkOut.map { Double($0) }
            }
            guard let v = value else { return nil }
            return WidgetChartPoint(date: date, value: v)
        }
    }
    
    private func downsample(_ points: [WidgetChartPoint], maxCount: Int) -> [WidgetChartPoint] {
        guard points.count > maxCount else { return points }
        let stride = max(1, points.count / maxCount)
        return Swift.stride(from: 0, to: points.count, by: stride).map { points[$0] }
    }
    
    private func formatCurrentValue(_ value: Double?, indicator: LoadIndicator) -> String {
        guard let value else { return "--" }
        switch indicator {
        case .cpu, .memory, .disk:
            return String(format: "%.1f%%", value)
        case .networkIn, .networkOut:
            return formatBytes(Int64(value)) + "/s"
        }
    }
}

// MARK: - Views

struct LoadChartSmallView: View {
    let entry: LoadChartEntry
    
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
        } else {
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(entry.serverRegion)
                        .font(.caption2)
                    Text(entry.serverName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Text(entry.indicator.label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                if !entry.dataPoints.isEmpty {
                    Chart(entry.dataPoints) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(lineGradient)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    switch entry.indicator {
                                    case .cpu, .memory, .disk:
                                        Text("\(Int(v))\(entry.indicator.unit)")
                                            .font(.system(size: 8))
                                    case .networkIn, .networkOut:
                                        Text("\(formatBytes(Int64(v)))\(entry.indicator.unit)")
                                            .font(.system(size: 8))
                                    }
                                }
                            }
                        }
                    }
                    .chartLegend(.hidden)
                }
                Spacer()
                Text(entry.currentValue)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(currentValueColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isPercentageIndicator: Bool {
        switch entry.indicator {
        case .cpu, .memory, .disk: return true
        case .networkIn, .networkOut: return false
        }
    }

    private var fixedColor: Color {
        switch entry.indicator {
        case .cpu, .memory, .disk: return .green
        case .networkIn: return .cyan
        case .networkOut: return .purple
        }
    }

    private var lineGradient: AnyShapeStyle {
        if isPercentageIndicator {
            return AnyShapeStyle(.linearGradient(
                colors: [.red, .orange, .green],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        return AnyShapeStyle(fixedColor)
    }

    private var currentValueColor: Color {
        if isPercentageIndicator {
            let value = entry.dataPoints.last?.value ?? 0
            if value >= 80 { return .red }
            if value >= 60 { return .orange }
            return .green
        }
        return fixedColor
    }
}

struct LoadChartMediumView: View {
    let entry: LoadChartEntry
    
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
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 4) {
                        Text(entry.serverRegion)
                            .font(.caption)
                        Text(entry.serverName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(entry.indicator.label): \(entry.currentValue)")
                        .font(.caption)
                        .foregroundStyle(currentValueColor)
                }

                if !entry.dataPoints.isEmpty {
                    Chart(entry.dataPoints) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(lineGradient)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    switch entry.indicator {
                                    case .cpu, .memory, .disk:
                                        Text("\(Int(v))%")
                                            .font(.caption2)
                                    case .networkIn, .networkOut:
                                        Text(formatBytes(Int64(v)))
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                    .chartLegend(.hidden)
                } else {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("No data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var isPercentageIndicator: Bool {
        switch entry.indicator {
        case .cpu, .memory, .disk: return true
        case .networkIn, .networkOut: return false
        }
    }

    private var fixedColor: Color {
        switch entry.indicator {
        case .cpu, .memory, .disk: return .green
        case .networkIn: return .cyan
        case .networkOut: return .purple
        }
    }

    private var lineGradient: AnyShapeStyle {
        if isPercentageIndicator {
            return AnyShapeStyle(.linearGradient(
                colors: [.red, .orange, .green],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        return AnyShapeStyle(fixedColor)
    }

    private var currentValueColor: Color {
        if isPercentageIndicator {
            let value = entry.dataPoints.last?.value ?? 0
            if value >= 80 { return .red }
            if value >= 60 { return .orange }
            return .green
        }
        return fixedColor
    }
}

// MARK: - Widget

struct LoadChartWidget: Widget {
    let kind: String = "LoadChartWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectLoadChartIntent.self, provider: LoadChartProvider()) { entry in
            LoadChartSmallOrMediumView(entry: entry)
                .widgetBG()
        }
        .configurationDisplayName("Load Chart")
        .description("View server load over time.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct LoadChartSmallOrMediumView: View {
    let entry: LoadChartEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            LoadChartSmallView(entry: entry)
        default:
            LoadChartMediumView(entry: entry)
        }
    }
}
