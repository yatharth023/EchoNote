//
//  TranscriptSearchBar.swift
//  EchoNote
//

import SwiftUI

struct TranscriptSearchBar: View {

    @Bindable var searchManager: TranscriptSearchManager
    var onNavigate: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search transcript...", text: $searchManager.query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Search transcript")

                if !searchManager.query.isEmpty {
                    Button {
                        searchManager.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            if !searchManager.query.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 16) {
                    Button {
                        searchManager.previousMatch()
                        onNavigate?()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    .disabled(!searchManager.hasMatches)
                    .accessibilityLabel("Previous match")

                    Text(searchManager.currentMatchDisplay)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(searchManager.hasMatches
                            ? "Match \(searchManager.currentMatchIndex + 1) of \(searchManager.totalMatches)"
                            : "No matches found")

                    Button {
                        searchManager.nextMatch()
                        onNavigate?()
                    } label: {
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                    }
                    .disabled(!searchManager.hasMatches)
                    .accessibilityLabel("Next match")
                }
                .padding(.vertical, 4)
            }
        }
    }
}
