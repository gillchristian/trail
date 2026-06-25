//
//  ContentView.swift
//  Track
//
//  Created by Christian Gill on 25/06/2026.
//

import SwiftUI

/// TRACK-000 smoke screen — proves a SwiftUI app builds + runs in the Simulator, and that the
/// Trail-derived dark palette (project-brief.md → Visual design) renders. The real Races-list
/// shell is TRACK-001 (WI-1); keep this minimal.
struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 2/255, green: 6/255, blue: 23/255)        // #020617 — slate-950, Trail's ground
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(red: 251/255, green: 191/255, blue: 36/255))  // #fbbf24 amber
                Text("Track")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("race-day companion")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

#Preview {
    ContentView()
}
