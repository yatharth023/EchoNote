//
//  SessionDetailView.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 04/06/26.
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {

    @Environment(\.modelContext) private var modelContext
    let session: EchoSession

    @State private var searchText: String = ""
    @State private var isEditingTitle: Bool = false
    @State private var editedTitle: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sessionInfoCard

                Divider()

                transcriptSection
            }
            .padding()
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search in transcript...")
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
            ForEach(filteredChunks) { chunk in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formattedTimestamp(chunk.timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(chunk.rawText)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if searchText.isEmpty {
                        Divider()
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var filteredChunks: [TranscriptionChunk] {
        let sortedChunks = session.chunks.sorted { $0.timestamp < $1.timestamp }

        if searchText.isEmpty {
            return sortedChunks
        } else {
            return sortedChunks.filter { chunk in
                chunk.rawText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func saveTitle() {
        session.title = editedTitle
        do {
            try modelContext.save()
            print("✅ Updated session title: \(editedTitle)")
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
}
