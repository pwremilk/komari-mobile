//
//  PingTaskAppEntity.swift
//  Komari Widget
//
//  Created by Junhui Lou on 3/23/26.
//

import AppIntents

struct PingTaskAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Ping Task"
    static var defaultQuery = PingTaskEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct PingTaskEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PingTaskAppEntity] {
        guard WidgetKMCore.isConfigured else { return [] }
        do {
            try await WidgetDataProvider.ensureAuth()
            let allTasks = try await fetchAllPingTasks()
            return identifiers.compactMap { id in
                allTasks.first { $0.id == id }
            }
        } catch {
            return []
        }
    }

    func suggestedEntities() async throws -> [PingTaskAppEntity] {
        guard WidgetKMCore.isConfigured else { return [] }
        try await WidgetDataProvider.ensureAuth()
        return try await fetchAllPingTasks()
    }

    func defaultResult() async -> PingTaskAppEntity? {
        nil
    }

    private func fetchAllPingTasks() async throws -> [PingTaskAppEntity] {
        let nodes = try await WidgetDataProvider.getNodes()
        var seenIds = Set<String>()
        var entities: [PingTaskAppEntity] = []

        for node in nodes.values.sorted(by: { $0.weight < $1.weight }).prefix(5) {
            guard let pingData = try? await WidgetDataProvider.getPingRecords(uuid: node.uuid, hours: 1) else { continue }
            for task in pingData.tasks ?? [] {
                let taskId = String(task.id)
                if seenIds.insert(taskId).inserted {
                    entities.append(PingTaskAppEntity(id: taskId, name: task.name))
                }
            }
        }

        return entities
    }
}
