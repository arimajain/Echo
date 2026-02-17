//
//  EchoApp.swift
//  Echo
//
//  Created by Ari on 06/02/26.
//

import SwiftUI

@main
struct EchoApp: App {
    init() {
        // Pre-warm haptic engine on app launch to avoid blocking main thread later
        // This ensures the engine is ready before any views need it
        _ = HapticManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            EchoRootTabView()
        }
    }
}
