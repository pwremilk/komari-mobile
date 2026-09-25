//
//  UsageBar.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/18/26.
//

import SwiftUI

struct UsageBar: View {
    let label: String
    let value: Double // 0-100

    private var barColor: Color {
        if value >= 80 { return .red }
        if value >= 60 { return .orange }
        return .green
    }

    private var clampedValue: Double {
        min(max(value, 0), 100)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(clampedValue, specifier: "%.1f")%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 8)
                    Capsule()
                        .fill(barColor)
                        .frame(width: proxy.size.width * clampedValue / 100, height: 8)
                        .animation(.smooth(duration: 0.5), value: clampedValue)
                }
            }
            .frame(height: 8)
        }
    }
}
