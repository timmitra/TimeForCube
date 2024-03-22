//
//  TimeForCubeApp.swift
//  TimeForCube
//
//  Created by Tim Mitra on 2023-12-15.
//

import SwiftUI

@main
struct TimeForCubeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.windowStyle(.volumetric)

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }.immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
