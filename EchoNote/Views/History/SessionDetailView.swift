//
//  SessionDetailView.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 04/06/26.
//

import SwiftUI
import SwiftData
import CoreSpotlight

struct SessionDetailView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    let session: EchoSession

    @State private var searchManager = TranscriptSearchManager()
    @State private var isEditingTitle: Bool = false
    @State private var editedTitle: String = ""
    @State private var scrollTarget: Int?

    var body: some View {
        VStack(spacing: 0) {
            TranscriptSearchBar(searchManager: searchManager) {
                scrollTarget = searchManager.currentMatch?.chunkIndex
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        sessionInfoCard

                        Divider()

                        transcriptSection
                    }
                    .padding()
                }
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(settings.scrollAnimation) {
                        proxy.scrollTo("chunk-\(target)", anchor: .center)
                    }
                    scrollTarget = nil
                }
                .onChange(of: searchManager.currentMatchIndex) { _, _ in
                    scrollTarget = searchManager.currentMatch?.chunkIndex
                }
            }
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isEditingTitle = true
                    editedTitle = session.title
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .alert("Edit Session Title", isPresented: $isEditingTitle) {
            TextField("Title", text: $editedTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveTitle()
            }
        }
        .onAppear {
            let sortedChunks = session.chunks.sorted { $0.timestamp < $1.timestamp }
            searchManager.setContent(sortedChunks.map(\.rawText))
        }
    }

    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.title.isEmpty ? "Untitled Session" : session.title)
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 20) {
                Label(formattedDate, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(formattedDuration, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !session.chunks.isEmpty {
                Label("\(session.chunks.count) segments", systemImage: "text.alignleft")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.headline)

            if session.chunks.isEmpty {
                ContentUnavailableView {
                    Label("No Transcript", systemImage: "doc.text")
                } description: {
                    Text("This session has no recorded text")
                }
                .frame(height: 200)
            } else {
                transcriptContent
            }
        }
    }

    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(sortedChunks.enumerated()), id: \.element.id) { index, chunk in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formattedTimestamp(chunk.timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(searchManager.highlightedText(for: chunk.rawText, chunkIndex: index))
                        .font(settings.transcriptFont)
                        .foregroundStyle(settings.transcriptForeground)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(settings.highContrast ? 8 : 0)
                        .background(settings.transcriptBackground,
                                    in: RoundedRectangle(cornerRadius: 8))

                    Divider()
                }
                .padding(.vertical, 4)
                .id("chunk-\(index)")
            }
        }
    }

    private var sortedChunks: [TranscriptionChunk] {
        session.chunks.sorted { $0.timestamp < $1.timestamp }
    }

    private func saveTitle() {
        session.title = editedTitle
        do {
            try modelContext.save()
            print("✅ Updated session title: \(editedTitle)")
            SpotlightIndexer.index(session: session)
        } catch {
            print("❌ Failed to save title: \(error)")
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: session.createdAt)
    }

    private var formattedDuration: String {
        let minutes = Int(session.durationSeconds) / 60
        let seconds = Int(session.durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: EchoSession.self, configurations: config)

    let session = EchoSession(
        title: "Sample Lecture",
        durationSeconds: 180
    )
    container.mainContext.insert(session)

    return SessionDetailView(session: session)
        .modelContainer(container)
        .environment(AppSettings())
}
