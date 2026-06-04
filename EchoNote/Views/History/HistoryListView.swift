//
//  HistoryListView.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 04/06/26.
//

import SwiftUI
import SwiftData

struct HistoryListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoSession.createdAt, order: .reverse) private var sessions: [EchoSession]

    @State private var searchText: String = ""
    @State private var spotlightNavigationSession: EchoSession?
    @State private var showSpotlightDetail: Bool = false

    // FEATURE 3: Spotlight deep-link binding
    @Binding var spotlightSessionID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if filteredSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionList
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search transcripts...")
            .navigationDestination(isPresented: $showSpotlightDetail) {
                if let session = spotlightNavigationSession {
                    SessionDetailView(session: session)
                }
            }
            .onChange(of: spotlightSessionID) { _, newID in
                if let sessionID = newID {
                    navigateToSession(id: sessionID)
                    spotlightSessionID = nil
                }
            }
            .onAppear {
                if let sessionID = spotlightSessionID {
                    navigateToSession(id: sessionID)
                    spotlightSessionID = nil
                }
            }
        }
    }

    private func navigateToSession(id: UUID) {
        guard let session = sessions.first(where: { $0.id == id }) else {
            print("⚠️ Session not found for Spotlight ID: \(id)")
            return
        }
        print("🔍 Navigating to session from Spotlight: \(session.title)")
        spotlightNavigationSession = session
        showSpotlightDetail = true
    }

    private var sessionList: some View {
        List {
            ForEach(filteredSessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionRowView(session: session)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteSession(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Recordings", systemImage: "waveform.slash")
        } description: {
            Text(searchText.isEmpty
                ? "Your recorded sessions will appear here"
                : "No sessions match '\(searchText)'")
        }
    }

    private var filteredSessions: [EchoSession] {
        if searchText.isEmpty {
            return sessions
        } else {
            return sessions.filter { session in
                session.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func deleteSession(_ session: EchoSession) {
        modelContext.delete(session)
        do {
            try modelContext.save()
            print("✅ Deleted session: \(session.title)")
        } catch {
            print("❌ Failed to delete session: \(error)")
        }
    }
}

struct SessionRowView: View {

    let session: EchoSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.title.isEmpty ? "Untitled Session" : session.title)
                .font(.headline)
                .lineLimit(1)

            HStack {
                Label(formattedDate, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Label(formattedDuration, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.createdAt)
    }

    private var formattedDuration: String {
        let minutes = Int(session.durationSeconds) / 60
        let seconds = Int(session.durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    HistoryListView(spotlightSessionID: .constant(nil))
        .modelContainer(for: EchoSession.self, inMemory: true)
}
