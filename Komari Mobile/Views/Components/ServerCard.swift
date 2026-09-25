//
//  ServerCard.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI

struct ServerCard: View {
    let node: NodeData
    let status: NodeLiveStatus?
    let isOnline: Bool

    private var cpuUsage: Double { status?.cpuUsage ?? 0 }

    private var memoryUsagePercent: Double {
        guard let status, status.memoryTotal > 0 else { return 0 }
        return Double(status.memoryUsed) / Double(status.memoryTotal) * 100
    }

    private var diskUsagePercent: Double {
        guard let status, status.diskTotal > 0 else { return 0 }
        return Double(status.diskUsed) / Double(status.diskTotal) * 100
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            gaugeSection
            networkSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            CountryFlag(countryFlag: node.region)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 5) {
                    Circle()
                        .fill(isOnline ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                        .shadow(color: (isOnline ? Color.green : Color.red).opacity(0.6), radius: 4)

                    Text(isOnline ? "Online" : "Offline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if isOnline, let status {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                        Text(formatTimeInterval(seconds: status.uptime, shortened: true))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Gauge Rings

    private var gaugeSection: some View {
        HStack {
            GaugeRing(label: "CPU", value: cpuUsage)
            Spacer()
            GaugeRing(label: "RAM", value: memoryUsagePercent)
            Spacer()
            GaugeRing(label: "Disk", value: diskUsagePercent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Network

    private var networkSection: some View {
        HStack {
            // Speed column
            VStack(alignment: .leading, spacing: 3) {
                Label {
                    Text("Speed")
                } icon: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

                networkRow(icon: "arrow.up", color: .teal, text: "\(formatBytes(status?.networkOutSpeed ?? 0))/s")
                networkRow(icon: "arrow.down", color: .blue, text: "\(formatBytes(status?.networkInSpeed ?? 0))/s")
            }

            Spacer()

            // Traffic column
            VStack(alignment: .trailing, spacing: 3) {
                Label {
                    Text("Traffic")
                } icon: {
                    Image(systemName: "chart.bar.fill")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

                networkRow(icon: "arrow.up", color: .teal, text: formatBytes(status?.networkOutTotal ?? 0))
                networkRow(icon: "arrow.down", color: .blue, text: formatBytes(status?.networkInTotal ?? 0))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func networkRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Gauge Ring

struct GaugeRing: View {
    let label: String
    let value: Double

    private let lineWidth: CGFloat = 5
    private let size: CGFloat = 52

    private var clampedValue: Double { min(max(value, 0), 100) }

    private var ringColor: Color {
        if clampedValue >= 80 { return .red }
        if clampedValue >= 60 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color(UIColor.systemGray5), lineWidth: lineWidth)

                // Value ring
                Circle()
                    .trim(from: 0, to: clampedValue / 100)
                    .stroke(ringColor.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.3), radius: 3)
                    .animation(.easeOut(duration: 0.6), value: clampedValue)

                // Center percentage
                Text("\(Int(clampedValue))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    
            }
            .frame(width: size, height: size)

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
