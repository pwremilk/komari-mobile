//
//  PingChartView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/18/26.
//

import SwiftUI
import Charts

enum PingPeriod: String, CaseIterable {
    case oneHour = "1h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case oneDay = "1d"

    var hours: Int {
        switch self {
        case .oneHour: 1
        case .sixHours: 6
        case .twelveHours: 12
        case .oneDay: 24
        }
    }
}

struct PingChartView: View {
    var node: NodeData
    @State private var period: PingPeriod = .oneHour
    @State private var pingRecords: [PingRecord] = []
    @State private var tasks: [PingTaskInfo] = []
    @State private var loadingState: LoadingState = .idle
    @State private var hiddenTaskIds: Set<Int> = []

    private static let taskColors: [Color] = [
        .red, .green, .blue, .orange, .purple, .teal, .pink, .yellow
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                contentSection
            }
            .padding()
        }
        .onAppear {
            fetchPingRecords()
        }
        .onChange(of: period) {
            pingRecords = []
            tasks = []
            loadingState = .idle
            fetchPingRecords()
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(PingPeriod.allCases, id: \.rawValue) { p in
                Text(p.rawValue)
                    .tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var contentSection: some View {
        Group {
            switch loadingState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .transition(.blurReplace)
            case .loaded:
                if tasks.isEmpty {
                    Text("No Data")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .transition(.blurReplace)
                } else {
                    VStack(spacing: 10) {
                        taskSummaryCard
                        pingChart
                    }
                    .transition(.blurReplace)
                }
            case .error(let message):
                VStack(spacing: 10) {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        fetchPingRecords()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .transition(.blurReplace)
            }
        }
        .animation(.smooth(duration: 0.3), value: loadingState)
    }

    private var taskSummaryCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                let isHidden = hiddenTaskIds.contains(task.id)
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        if isHidden {
                            hiddenTaskIds.remove(task.id)
                        } else {
                            hiddenTaskIds.insert(task.id)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Self.taskColors[index % Self.taskColors.count])
                            .frame(width: 4, height: 24)
                            .opacity(isHidden ? 0.3 : 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.name)
                                .font(.system(size: 14, weight: .semibold))
                            HStack(spacing: 8) {
                                if let latest = task.latest {
                                    Text("\(Int(latest)) ms")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let loss = task.loss {
                                    Text(String(format: "%.1f%% loss", loss))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let avg = task.avg {
                                Text("avg \(Int(avg)) ms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let p99 = task.p99, let p50 = task.p50 {
                                Text("p50 \(Int(p50)) / p99 \(Int(p99))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Image(systemName: isHidden ? "eye.slash" : "eye")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .opacity(isHidden ? 0.4 : 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < tasks.count - 1 {
                    Divider()
                        .padding(.leading, 24)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.08), radius: 5, x: 5, y: 5)
                .shadow(color: .black.opacity(0.06), radius: 5, x: -5, y: -5)
        )
    }

    private var pingChart: some View {
        let chartPoints = buildChartData()
        return VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Ping")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                if chartPoints.isEmpty {
                    Text("No Data")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    Chart(chartPoints, id: \.id) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Latency", point.value),
                            series: .value("Task", point.taskName)
                        )
                        .foregroundStyle(point.color)
                        .interpolationMethod(.linear)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(v, specifier: "%.0f")ms")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartForegroundStyleScale(range: tasks.enumerated().compactMap { index, task in
                        hiddenTaskIds.contains(task.id) ? nil : Self.taskColors[index % Self.taskColors.count]
                    })
                    .frame(height: 200)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.08), radius: 5, x: 5, y: 5)
                .shadow(color: .black.opacity(0.06), radius: 5, x: -5, y: -5)
        )
    }

    private struct PingChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let taskName: String
        let color: Color
    }

    private func buildChartData() -> [PingChartPoint] {
        var points: [PingChartPoint] = []
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.name) })

        for record in pingRecords {
            guard let taskId = record.taskId,
                  !hiddenTaskIds.contains(taskId),
                  let timeStr = record.time,
                  let date = ServerDetailMonitorView.parseDate(timeStr),
                  let value = record.value,
                  value >= 0,
                  let taskName = taskMap[taskId] else { continue }

            let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) ?? 0
            let color = Self.taskColors[taskIndex % Self.taskColors.count]
            points.append(PingChartPoint(date: date, value: value, taskName: taskName, color: color))
        }
        return points
    }

    private func fetchPingRecords() {
        loadingState = .loading
        Task {
            do {
                let result = try await RecordHandler.getPingRecords(uuid: node.uuid, hours: period.hours)
                withAnimation {
                    pingRecords = result.records ?? []
                    tasks = result.tasks ?? []
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
