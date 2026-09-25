//
//  EditServerView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 3/3/26.
//

import SwiftUI

private enum TrafficUnit: Int64, CaseIterable {
    case mb = 1_048_576
    case gb = 1_073_741_824
    case tb = 1_099_511_627_776

    var title: String {
        switch self {
        case .mb: "MB"
        case .gb: "GB"
        case .tb: "TB"
        }
    }
}

struct EditServerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: KMState

    let node: NodeData

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Read-only
    @State private var token: String = ""

    // Basic
    @State private var name: String = ""
    @State private var tags: String = ""
    @State private var group: String = ""
    @State private var remark: String = ""
    @State private var publicRemark: String = ""
    @State private var hidden: Bool = false

    // Traffic
    @State private var trafficLimitEnabled: Bool = false
    @State private var trafficLimitValue: String = ""
    @State private var trafficLimitUnit: TrafficUnit = .gb
    @State private var trafficLimitType: String = "sum"

    // Billing
    @State private var price: String = ""
    @State private var billingCycle: Int = 0
    @State private var currency: String = ""
    @State private var hasExpiration: Bool = false
    @State private var expiredAt: Date = Date()
    @State private var autoRenewal: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    editForm
                }
            }
            .navigationTitle("Edit Server")
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
                        } else {
                            Button("Done") {
                                save()
                            }
                        }
                    }
                }
            }
            .task { await loadData() }
        }
    }

    // MARK: - Form

    private var editForm: some View {
        Form {
            Section("Basic") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !token.isEmpty {
                    LabeledContent("Token") {
                        Text(token)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }

                TextField("Tags (semicolon-separated)", text: $tags)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Group", text: $group)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Remarks") {
                TextField("Private Remark", text: $remark, axis: .vertical)
                    .lineLimit(3...6)

                TextField("Public Remark", text: $publicRemark, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Toggle("Hidden", isOn: $hidden)
            }

            Section("Traffic Limit") {
                Toggle("Enable Traffic Limit", isOn: $trafficLimitEnabled)

                if trafficLimitEnabled {
                    TextField("Value", text: $trafficLimitValue)
                        .keyboardType(.decimalPad)

                    Picker("Unit", selection: $trafficLimitUnit) {
                        ForEach(TrafficUnit.allCases, id: \.self) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Type", selection: $trafficLimitType) {
                        Text("Sum").tag("sum")
                        Text("Max").tag("max")
                        Text("Min").tag("min")
                        Text("Upload").tag("up")
                        Text("Download").tag("down")
                    }
                }
            }

            Section("Billing") {
                TextField("Price", text: $price)
                    .keyboardType(.decimalPad)

                TextField("Currency", text: $currency)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("Billing Cycle", selection: $billingCycle) {
                    Text("None").tag(0)
                    Text("Monthly").tag(30)
                    Text("Quarterly").tag(92)
                    Text("Semi-Annual").tag(184)
                    Text("Annual").tag(365)
                    Text("Biennial").tag(730)
                    Text("Triennial").tag(1095)
                    Text("Quinquennial").tag(1825)
                    Text("One-Time").tag(-1)
                }

                Toggle("Expiration Date", isOn: $hasExpiration)
                if hasExpiration {
                    DatePicker("Expires", selection: $expiredAt, displayedComponents: .date)
                }

                Toggle("Auto Renewal", isOn: $autoRenewal)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Populate from NodeData immediately
        name = node.name
        tags = node.tags ?? ""
        group = node.group ?? ""
        publicRemark = node.publicRemark ?? ""
        hidden = node.hidden ?? false
        price = node.price.map { formatNumber($0) } ?? ""
        billingCycle = snapBillingCycle(node.billingCycle ?? 0)
        currency = node.currency ?? ""

        if let limit = node.trafficLimit, limit > 0 {
            trafficLimitEnabled = true
            let (value, unit) = convertFromBytes(limit)
            trafficLimitValue = value
            trafficLimitUnit = unit
        }
        trafficLimitType = node.trafficLimitType ?? "sum"

        // Fetch admin data for token, remark, expiredAt, autoRenewal
        do {
            let adminNodes = try await AdminHandler.getAdminNodes()
            if let adminNode = adminNodes.first(where: { $0.uuid == node.uuid }) {
                token = adminNode.token ?? ""
                remark = adminNode.remark ?? ""
                autoRenewal = adminNode.autoRenewal ?? false
                if let expStr = adminNode.expiredAt, let date = parseDate(expStr) {
                    hasExpiration = true
                    expiredAt = date
                }
            }
        } catch {
            // Proceed without admin-only fields
        }

        isLoading = false
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                var changes: [String: Any] = [
                    "name": name,
                    "tags": tags,
                    "group": group,
                    "remark": remark,
                    "public_remark": publicRemark,
                    "hidden": hidden,
                    "auto_renewal": autoRenewal,
                ]

                // Traffic limit
                if trafficLimitEnabled, let value = Double(trafficLimitValue), value > 0 {
                    changes["traffic_limit"] = Int64(value * Double(trafficLimitUnit.rawValue))
                    changes["traffic_limit_type"] = trafficLimitType
                } else {
                    changes["traffic_limit"] = 0
                }

                // Price
                if let priceValue = Double(price) {
                    changes["price"] = priceValue
                } else {
                    changes["price"] = 0
                }
                changes["billing_cycle"] = billingCycle
                changes["currency"] = currency

                // Expiration
                if hasExpiration {
                    let formatter = ISO8601DateFormatter()
                    changes["expired_at"] = formatter.string(from: expiredAt)
                }

                try await AdminHandler.editClient(uuid: node.uuid, changes: changes)
                await state.refreshAll()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    // MARK: - Helpers

    private func convertFromBytes(_ bytes: Int64) -> (String, TrafficUnit) {
        if bytes >= TrafficUnit.tb.rawValue {
            return (formatNumber(Double(bytes) / Double(TrafficUnit.tb.rawValue)), .tb)
        } else if bytes >= TrafficUnit.gb.rawValue {
            return (formatNumber(Double(bytes) / Double(TrafficUnit.gb.rawValue)), .gb)
        } else {
            return (formatNumber(Double(bytes) / Double(TrafficUnit.mb.rawValue)), .mb)
        }
    }

    private func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.2f", value)
    }

    private func snapBillingCycle(_ days: Int) -> Int {
        switch days {
        case 27...32: return 30
        case 87...95: return 92
        case 175...185: return 184
        case 360...370: return 365
        case 720...750: return 730
        case 1080...1150: return 1095
        case 1800...1850: return 1825
        case -1: return -1
        default: return days
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) { return date }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = formatter.date(from: string) { return date }

        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
