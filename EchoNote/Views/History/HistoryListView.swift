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
                    SessionRowView(session: session, query: trimmedQuery)
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

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredSessions: [EchoSession] {
        let query = trimmedQuery
        guard !query.isEmpty else { return sessions }

        return sessions.filter { session in
            if session.title.localizedCaseInsensitiveContains(query) {
                return true
            }
            // Search across all transcript chunks
            return session.chunks.contains { chunk in
                chunk.rawText.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private func deleteSession(_ session: EchoSession) {
        SpotlightIndexer.remove(session: session)
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
    var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(highlightedTitle)
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

            if !query.isEmpty,
               let snippet = transcriptSnippet(matching: query) {
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var displayTitle: String {
        session.title.isEmpty ? "Untitled Session" : session.title
    }

    private var highlightedTitle: AttributedString {
        var attributed = AttributedString(displayTitle)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let range = attributed.range(of: trimmed,
                                           options: .caseInsensitive) else {
            return attributed
        }
        attributed[range].backgroundColor = .yellow
        attributed[range].foregroundColor = .black
        return attributed
    }

    private func transcriptSnippet(matching query: String) -> AttributedString? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for chunk in session.chunks.sorted(by: { $0.timestamp < $1.timestamp }) {
            let text = chunk.rawText
            guard let foundRange = text.range(of: trimmed, options: .caseInsensitive) else {
                continue
            }

            let windowRadius = 40
            let lower = text.index(foundRange.lowerBound,
                                   offsetBy: -windowRadius,
                                   limitedBy: text.startIndex) ?? text.startIndex
            let upper = text.index(foundRange.upperBound,
                                   offsetBy: windowRadius,
                                   limitedBy: text.endIndex) ?? text.endIndex

            let leadingEllipsis = lower > text.startIndex ? "…" : ""
            let trailingEllipsis = upper < text.endIndex ? "…" : ""
            let snippetString = leadingEllipsis + String(text[lower..<upper]) + trailingEllipsis

            var attributed = AttributedString(snippetString)
            if let highlightRange = attributed.range(of: trimmed, options: .caseInsensitive) {
                attributed[highlightRange].backgroundColor = .yellow
                attributed[highlightRange].foregroundColor = .black
            }
            return attributed
        }
        return nil
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
        .environment(AppSettings())
}
