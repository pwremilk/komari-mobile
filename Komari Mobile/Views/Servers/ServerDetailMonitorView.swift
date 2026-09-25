//
//  ServerDetailMonitorView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI
import Charts

enum LoadPeriod: String, CaseIterable {
    case fourHours = "4h"
    case oneDay = "1d"
    case sevenDays = "7d"
    case thirtyDays = "30d"

    var hours: Int {
        switch self {
        case .fourHours: 4
        case .oneDay: 24
        case .sevenDays: 168
        case .thirtyDays: 720
        }
    }

    var chartPeriod: ChartPeriod {
        switch self {
        case .fourHours: .fourHours
        case .oneDay: .oneDay
        case .sevenDays: .sevenDays
        case .thirtyDays: .thirtyDays
        }
    }
}

struct ServerDetailMonitorView: View {
    var node: NodeData
    @State private var period: LoadPeriod = .oneDay
    @State private var records: [NodeRecord] = []
    @State private var loadingState: LoadingState = .idle

    private static let rfc3339Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let rfc3339FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parseDate(_ string: String) -> Date? {
        if let date = rfc3339Formatter.date(from: string) {
            return date
        }
        return rfc3339FractionalFormatter.date(from: string)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                metricsSection
            }
            .padding()
        }
        .onAppear {
            fetchRecords()
        }
        .onChange(of: period) { _ in
            records = []
            loadingState = .idle
            fetchRecords()
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(LoadPeriod.allCases, id: \.rawValue) { p in
                Text(p.rawValue)
                    .tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var metricsSection: some View {
        Group {
            switch loadingState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .transition(.opacity)
            case .loaded:
                if records.isEmpty {
                    Text("No Data")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 10) {
                        cpuChart
                        memoryChart
                        diskChart
                        networkSpeedChart
                        connectionsChart
                        processChart
                        gpuChart
                    }
                    .transition(.opacity)
                }
            case .error(let message):
                VStack(spacing: 10) {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        fetchRecords()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.3), value: loadingState)
    }

    @ViewBuilder
    private func chartCard<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        VStack(spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.08), radius: 5, x: 5, y: 5)
                .shadow(color: .black.opacity(0.06), radius: 5, x: -5, y: -5)
        )
    }

    private var currentChartPeriod: ChartPeriod { period.chartPeriod }

    private var cpuChart: some View {
        let points = records.compactMap { record -> MetricsDataPoint? in
            guard let cpu = record.cpuUsage,
                  let timeStr = record.time,
                  let date = Self.parseDate(timeStr) else { return nil }
            return MetricsDataPoint(date: date, value: Double(cpu))
        }
        return chartCard {
            MetricsChart(title: "CPU", dataPoints: points, unit: "%", color: .blue, period: currentChartPeriod)
        }
    }

    private var memoryChart: some View {
        let points = records.compactMap { record -> MetricsDataPoint? in
            guard let used = record.memoryUsed, let total = record.memoryTotal, total > 0,
                  let timeStr = record.time,
                  let date = Self.parseDate(timeStr) else { return nil }
            return MetricsDataPoint(date: date, value: Double(used) / Double(total) * 100)
        }
        return chartCard {
            MetricsChart(title: "Memory", dataPoints: points, unit: "%", color: .green, period: currentChartPeriod)
        }
    }

    private var diskChart: some View {
        let points = records.compactMap { record -> MetricsDataPoint? in
            guard let used = record.diskUsed, let total = record.diskTotal, total > 0,
                  let timeStr = record.time,
                  let date = Self.parseDate(timeStr) else { return nil }
            return MetricsDataPoint(date: date, value: Double(used) / Double(total) * 100)
        }
        return chartCard {
            MetricsChart(title: "Disk", dataPoints: points, unit: "%", color: .orange, period: currentChartPeriod)
        }
    }

    private var networkSpeedChart: some View {
        let inPoints = records.compactMap { record -> MetricsDataPoint? in
            guard let netIn = record.networkIn,
                  let timeStr = record.time,
                  let date = Self.parseDate(timeStr) else { return nil }
            return MetricsDataPoint(date: date, value: Double(netIn) / 1024)
        }
        let outPoints = records.compactMap { record -> MetricsDataPoint? in
            guard let netOut = record.networkOut,
                  let timeStr = record.time,
                  let date = Self.parseDate(timeStr) else { return nil }
            return MetricsDataPoint(date: date, value: Double(netOut) / 1024)
        }
        return chartCard {
            MetricsMultiSeriesChart(
                title: "Network Speed",
                series: [
                    MetricsSeriesData(name: "In", dataPoints: inPoints, color: .purple),
                    MetricsSeriesData(name: "Out", dataPoints: outPoints, color: .red)
                ],
                unit: "KB/s",
                period: currentChartPeriod
            )
        }
    }

    private var connectionsChart: some View {
        let tcpPoints = records.compactMap { record -> MetricsDataPoint? in
            guard let tcp = record.connectionCount,
                  let timeStr = record.time,
                  let date = Self.parseDate(timeStr) else { return nil }
            return MetricsDataPoint(date: date, value: Double(tcp))
        }
        let udpPoints = records.compactMap { record -> MetricsDataPoint? in
            guard let udp = record.connectionCountUDP,
                  let timeStr = record.time,
                  let date = Self.parseDate(timeStr) else { return nil }
            return MetricsDataPoint(date: date, value: Double(udp))
        }
        return chartCard {
            MetricsMultiSeriesChart(
                title: "Connections",
                series: [
                    MetricsSeriesData(name: "TCP", dataPoints: tcpPoints, color: .blue),
                    MetricsSeriesData(name: "UDP", dataPoints: udpPoints, color: .teal)
                ],
                unit: "",
                period: currentChartPeriod
            )
        }
    }

    private var processChart: some View {
        let points = records.compactMap { record -> MetricsDataPoint? in
            guard let process = record.processCount,
                  let timeStr = record.time,
                  let date = Self.parseDate(timeStr) else { return nil }
            return MetricsDataPoint(date: date, value: Double(process))
        }
        return chartCard {
            MetricsChart(title: "Process", dataPoints: points, unit: "", color: .pink, period: currentChartPeriod)
        }
    }

    @ViewBuilder
    private var gpuChart: some View {
        let hasGPU = records.contains { $0.gpuUsage != nil }
        if hasGPU {
            let points = records.compactMap { record -> MetricsDataPoint? in
                guard let gpu = record.gpuUsage,
                      let timeStr = record.time,
                      let date = Self.parseDate(timeStr) else { return nil }
                return MetricsDataPoint(date: date, value: Double(gpu))
            }
            chartCard {
                MetricsChart(title: "GPU", dataPoints: points, unit: "%", color: .indigo, period: currentChartPeriod)
            }
        }
    }

    private func fetchRecords() {
        loadingState = .loading
        Task {
            do {
                let result = try await RecordHandler.getRecords(uuid: node.uuid, hours: period.hours)
                // Sort records by time ascending (matching komari-web behavior)
                let sorted = result.sorted { a, b in
                    guard let ta = a.time, let tb = b.time,
                          let da = Self.parseDate(ta), let db = Self.parseDate(tb) else { return false }
                    return da < db
                }
                withAnimation {
                    records = sorted
                    loadingState = .loaded
                }
            } catch {
                withAnimation {
                    loadingState = .error(error.localizedDescription)
                }
            }
        }
    }
}
