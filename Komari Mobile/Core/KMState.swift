//
//  KMState.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import Foundation
import SwiftUI

enum MainTab: String, CaseIterable {
    case servers = "servers"
    case settings = "settings"

    var systemName: String {
        switch self {
        case .servers: "server.rack"
        case .settings: "gearshape"
        }
    }

    var title: String {
        switch self {
        case .servers: String(localized: "Servers")
        case .settings: String(localized: "Settings")
        }
    }
}

class KMState: ObservableObject {
    @Published var pathServers: NavigationPath = .init()
    @Published var pathSettings: NavigationPath = .init()

    @Published var tab: MainTab = .servers

    @Published var dashboardLoadingState: LoadingState = .idle
    @Published var nodes: [NodeData] = .init()
    @Published var liveStatus: [String: NodeLiveStatus] = .init()
    @Published var onlineUUIDs: Set<String> = .init()
    private @Published var timer: Timer?

    var groupNames: [String] {
        let groups = nodes.compactMap { $0.group }.filter { !$0.isEmpty }
        return Array(Set(groups)).sorted()
    }

    func loadDashboard() {
        let link = KMCore.getKomariDashboardLink()
        guard !link.isEmpty else {
            dashboardLoadingState = .error("Dashboard is not properly configured.")
            return
        }

        dashboardLoadingState = .loading

        Task {
            do {
                // Attempt login if credentials are available
                let username = KMCore.getKomariDashboardUsername()
                let password = KMCore.getKomariDashboardPassword()
                if !username.isEmpty && !password.isEmpty {
                    try await AuthHandler.login(username: username, password: password)
                }

                try await loadNodes()
                try await refreshLiveStatus()
                dashboardLoadingState = .loaded
            } catch {
                withAnimation {
                    dashboardLoadingState = .error(error.localizedDescription)
                }
                return
            }
        }

        startAutoRefresh()
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task {
                try? await self?.refreshLiveStatus()
            }
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    private @Published var loadNodesTask: Task<Void, Error>?
    private @Published var refreshLiveStatusTask: Task<Void, Error>?

    func loadNodes() async throws {
        loadNodesTask?.cancel()

        loadNodesTask = Task {
            let nodesMap = try await NodeHandler.getNodes()

            guard !Task.isCancelled else { return }

            withAnimation {
                self.nodes = Array(nodesMap.values).sorted { $0.weight < $1.weight }
            }
        }

        try await loadNodesTask?.value
    }

    func refreshLiveStatus() async throws {
        refreshLiveStatusTask?.cancel()

        refreshLiveStatusTask = Task {
            let statusMap = try await NodeHandler.getNodesLatestStatus()

            guard !Task.isCancelled else { return }

            withAnimation {
                self.liveStatus = statusMap
                self.onlineUUIDs = Set(statusMap.values.filter { $0.online }.map { $0.client })
            }
        }

        try await refreshLiveStatusTask?.value
    }

    func refreshAll() async {
        try? await loadNodes()
        try? await refreshLiveStatus()
    }
}
