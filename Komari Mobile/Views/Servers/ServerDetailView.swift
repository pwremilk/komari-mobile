//
//  ServerDetailView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI

enum ServerDetailTab: String, CaseIterable, Identifiable {
    var id: String { self.rawValue }

    case status = "status"
    case load = "load"
    case ping = "ping"

    func localized() -> String {
        switch self {
        case .status:
            return String(localized: "Status")
        case .load:
            return String(localized: "Load")
        case .ping:
            return String(localized: "Ping")
        }
    }
}

struct ServerDetailView: View {
    @EnvironmentObject var state
    var uuid: String
    @State private var activeTab: ServerDetailTab = .status
    @State private var isShowEditServer: Bool = false

    var body: some View {
        let node = state.nodes.first(where: { $0.uuid == uuid })
        let status = state.liveStatus[uuid]
        let isOnline = state.onlineUUIDs.contains(uuid)

        Group {
            if let node {
                VStack {
                    if isOnline {
                        content(node: node, status: status)
                            .transition(.blurReplace)
                    } else {
                        ContentUnavailableView("Server Unavailable", systemImage: "square.stack.3d.up.slash.fill")
                            .transition(.blurReplace)
                    }
                }
                .animation(.smooth(duration: 0.3), value: isOnline)
                .navigationTitle(node.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowEditServer = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                }
                .sheet(isPresented: $isShowEditServer) {
                    EditServerView(node: node)
                }
            } else {
                ProgressView()
            }
        }
    }

    private func content(node: NodeData, status: NodeLiveStatus?) -> some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack {
                Picker("Section", selection: $activeTab) {
                    ForEach(ServerDetailTab.allCases) {
                        Text($0.localized())
                            .tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                Group {
                    switch(activeTab) {
                    case .status:
                        ServerDetailStatusView(node: node, status: status)
                            .transition(.blurReplace)
                    case .load:
                        ServerDetailMonitorView(node: node)
                            .transition(.blurReplace)
                    case .ping:
                        PingChartView(node: node)
                            .transition(.blurReplace)
                    }
                }
                .animation(.smooth(duration: 0.25), value: activeTab)
            }
        }
    }
}
