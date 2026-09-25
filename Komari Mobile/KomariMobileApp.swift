//
//  KomariMobileApp.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import SwiftUI

@main
struct KomariMobileApp: App {
    @StateObject var state = KMState()

    init() {
        KMCore.registerUserDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
    }
}
