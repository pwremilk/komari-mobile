//
//  HomeView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: KMState

    var body: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: kmBinding(for: \KMState.tab, on: state)) {
                Tab(value: MainTab.servers) {
                    ServerListView()
                } label: {
                    Label(MainTab.servers.title, systemImage: MainTab.servers.systemName)
                }
                
                Tab(value: MainTab.settings) {
                    SettingsView()
                } label: {
                    Label(MainTab.settings.title, systemImage: MainTab.settings.systemName)
                }
            }
        }
        else {
            TabView(selection: kmBinding(for: \KMState.tab, on: state)) {
                ServerListView()
                    .tabItem {
                        Label(MainTab.servers.title, systemImage: MainTab.servers.systemName)
                    }
                    .tag(MainTab.servers)
                
                SettingsView()
                    .tabItem {
                        Label(MainTab.settings.title, systemImage: MainTab.settings.systemName)
                    }
                    .tag(MainTab.settings)
            }
        }
    }
}
