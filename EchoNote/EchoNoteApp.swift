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
    @State private var showOnboarding: Bool = false
    @State private var viewModel = LiveTranscriptViewModel()
    @State private var settings = AppSettings()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            EchoSession.self,
            TranscriptionChunk.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                LiveTranscriptView(viewModel: viewModel)
                    .tabItem {
                        Label("Record", systemImage: "mic.circle")
                    }
                    .tag(0)

                HistoryListView(spotlightSessionID: $spotlightSessionID)
                    .tabItem {
                        Label("History", systemImage: "list.bullet")
                    }
                    .tag(1)

                SettingsView(viewModel: viewModel)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(2)
            }
            .environment(settings)
            .preferredColorScheme(settings.highContrast ? .light : nil)
            .onAppear {
                checkFirstLaunch()
                reindexAllSessionsInSpotlight()
            }
            .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                handleSpotlightActivity(userActivity)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                ModelSetupView(viewModel: viewModel) {
                    showOnboarding = false
                    UserDefaults.standard.set(true, forKey: "echoNote.hasCompletedOnboarding")
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func checkFirstLaunch() {
        let hasLaunched = UserDefaults.standard.bool(forKey: "echoNote.hasCompletedOnboarding")
        if !hasLaunched {
            showOnboarding = true
        }
    }

    private func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        guard let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        let components = uniqueIdentifier.components(separatedBy: ".")
        guard let uuidString = components.last, let sessionUUID = UUID(uuidString: uuidString) else {
            return
        }

        selectedTab = 1
        spotlightSessionID = sessionUUID
    }

    private func reindexAllSessionsInSpotlight() {
        let container = sharedModelContainer
        Task { @MainActor in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<EchoSession>()
            guard let sessions = try? context.fetch(descriptor) else { return }
            await SpotlightIndexer.indexAll(sessions)
        }
    }
}
