//
//  WidgetIntents.swift
//  Komari Widget
//
//  Created by Junhui Lou on 2/19/26.
//

import WidgetKit
import AppIntents

struct SelectServerIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Server"
    static var description: IntentDescription = "Choose a server to monitor"

    @Parameter(title: "Server")
    var server: ServerAppEntity?
}

struct SelectLoadChartIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Load Chart"
    static var description: IntentDescription = "Choose a server and load indicator"

    @Parameter(title: "Server")
    var server: ServerAppEntity?

    @Parameter(title: "Indicator", default: .cpu)
    var indicator: LoadIndicator
}

struct SelectPingIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Ping Chart"
    static var description: IntentDescription = "Choose a server and task for ping monitoring"

    @Parameter(title: "Server")
    var server: ServerAppEntity?

    @Parameter(title: "Task")
    var task: PingTaskAppEntity?
}
