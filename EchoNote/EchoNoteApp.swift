//
//  EchoNoteApp.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 03/06/26.
//

import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct EchoNoteApp: App {

    @State private var selectedTab: Int = 0
    @State private var spotlightSessionID: UUID?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            EchoSession.self,
            TranscriptionChunk.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ SwiftData ModelContainer initialized successfully")
            return container
        } catch {
            print("❌ FATAL: Could not create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                LiveTranscriptView()
                    .tabItem {
                        Label("Record", systemImage: "mic.circle")
                    }
                    .tag(0)

                HistoryListView(spotlightSessionID: $spotlightSessionID)
                    .tabItem {
                        Label("History", systemImage: "list.bullet")
                    }
                    .tag(1)
            }
            .onAppear {
                print("✅ EchoNote app launched successfully")
            }
            .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                handleSpotlightActivity(userActivity)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        guard let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            print("⚠️ No Spotlight identifier found in activity")
            return
        }

        print("🔍 Spotlight deep-link received: \(uniqueIdentifier)")

        // Extract UUID from identifier (format: "com.yatharth.EchoNote.sessions.<UUID>")
        let components = uniqueIdentifier.components(separatedBy: ".")
        guard let uuidString = components.last, let sessionUUID = UUID(uuidString: uuidString) else {
            print("⚠️ Could not extract session UUID from identifier")
            return
        }

        print("🔍 Navigating to session: \(sessionUUID)")

        // Switch to History tab and pass the session ID for navigation
        selectedTab = 1
        spotlightSessionID = sessionUUID
    }
}
