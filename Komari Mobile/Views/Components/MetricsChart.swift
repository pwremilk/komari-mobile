//
//  MetricsChart.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI
import Charts

struct MetricsDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Chart Period (for axis formatting)

enum ChartPeriod {
    case fourHours
    case oneDay
    case sevenDays
    case thirtyDays

    var xAxisFormat: Date.FormatStyle {
        switch self {
        case .fourHours:
            .dateTime.hour().minute()
        case .oneDay:
            .dateTime.hour().minute()
        case .sevenDays, .thirtyDays:
            .dateTime.month(.abbreviated).day()
        }
    }

    /// Interval in seconds for downsampling
    var downsampleInterval: TimeInterval {
        switch self {
        case .fourHours: 60            // 1 min  → ~240 pts
        case .oneDay: 15 * 60         // 15 min → ~96 pts
        case .sevenDays: 60 * 60      // 1 hour → ~168 pts
        case .thirtyDays: 2 * 60 * 60 // 2 hour → ~360 pts
        }
    }
}

// MARK: - Downsampling

/// Sorts data points by date and downsamples to regular intervals by averaging within buckets.
func downsampleDataPoints(_ points: [MetricsDataPoint], interval: TimeInterval) -> [MetricsDataPoint] {
    guard !points.isEmpty else { return [] }

    let sorted = points.sorted { $0.date < $1.date }

    // For very small datasets or very short intervals, skip downsampling
    if sorted.count <= 200 { return sorted }

    let startTime = sorted.first!.date.timeIntervalSince1970
    var buckets: [Int: (sum: Double, count: Int, date: Date)] = [:]

    for point in sorted {
        let bucketIndex = Int((point.date.timeIntervalSince1970 - startTime) / interval)
        if var existing = buckets[bucketIndex] {
            existing.sum += point.value
            existing.count += 1
            buckets[bucketIndex] = existing
        } else {
            // Use the midpoint of the bucket as the representative date
            let bucketDate = Date(timeIntervalSince1970: startTime + Double(bucketIndex) * interval + interval / 2)
            buckets[bucketIndex] = (sum: point.value, count: 1, date: bucketDate)
        }
    }

    return buckets.sorted { $0.key < $1.key }.map { _, bucket in
        MetricsDataPoint(date: bucket.date, value: bucket.sum / Double(bucket.count))
    }
}

struct MetricsChart: View {
    let title: String
    let dataPoints: [MetricsDataPoint]
    let unit: String
    let color: Color
    var period: ChartPeriod = .fourHours

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.top, 10)

            if dataPoints.isEmpty {
                Text("No Data")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                let processed = downsampleDataPoints(dataPoints, interval: period.downsampleInterval)
                Chart(processed) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(color.gradient)

                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(color.opacity(0.1).gradient)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(v, specifier: "%.0f")\(unit)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel(format: period.xAxisFormat)
                    }
                }
                .frame(height: 150)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }
}

struct MetricsSeriesData {
    let name: String
    let dataPoints: [MetricsDataPoint]
    let color: Color
}

struct MetricsMultiSeriesChart: View {
    let title: String
    let series: [MetricsSeriesData]
    let unit: String
    var period: ChartPeriod = .fourHours

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                ForEach(series, id: \.name) { s in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(s.color)
                            .frame(width: 8, height: 8)
                        Text(s.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            if series.allSatisfy({ $0.dataPoints.isEmpty }) {
                Text("No Data")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(series, id: \.name) { s in
                        let processed = downsampleDataPoints(s.dataPoints, interval: period.downsampleInterval)
                        ForEach(processed) { point in
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value(title, point.value),
                                series: .value("Series", s.name)
                            )
                            .foregroundStyle(s.color)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(v, specifier: "%.0f")\(unit)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: period.xAxisFormat)
                    }
                }
                .frame(height: 150)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }
}
