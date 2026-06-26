//
//  TrackApp.swift
//  Track
//
//  Created by Christian Gill on 25/06/2026.
//

import SwiftUI

@main
struct TrackApp: App {
    init() {
        // One-time UI-test affordance: start from empty persistent state. This lives in App.init
        // (which runs once per process) rather than in the stores' inits: SwiftUI re-evaluates a
        // view's `@State = Store()` default expression on every re-creation of that view, so a
        // destructive reset placed there repeats — and wipes data created earlier in the session.
        if CommandLine.arguments.contains("-uitest-reset") {
            RaceStorage().reset()
            TrackableLibraryStorage().reset()
        }
    }

    var body: some Scene {
        WindowGroup {
            RacesView()
        }
    }
}
