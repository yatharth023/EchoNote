//
//  SpotlightIndexer.swift
//  EchoNote
//

import Foundation
import CoreSpotlight

enum SpotlightIndexer {

    /// Indexes a single session so its title and a transcript preview become
    /// searchable from the system Spotlight UI. Re-running with the same
    /// `uniqueIdentifier` updates the existing entry.
    static func index(session: EchoSession) {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        let displayTitle = session.title.isEmpty ? "Untitled Session" : session.title
        attributes.title = displayTitle
        attributes.displayName = displayTitle
        attributes.contentDescription = session.contentPreview
        attributes.timestamp = session.createdAt
        attributes.keywords = displayTitle
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        let item = CSSearchableItem(
            uniqueIdentifier: session.spotlightUniqueIdentifier,
            domainIdentifier: EchoSession.spotlightDomainIdentifier,
            attributeSet: attributes
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                print("❌ Spotlight indexing failed: \(error)")
            }
        }
    }

    static func indexAll(_ sessions: [EchoSession]) async {
        let items: [CSSearchableItem] = sessions.map { session in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            let displayTitle = session.title.isEmpty ? "Untitled Session" : session.title
            attributes.title = displayTitle
            attributes.displayName = displayTitle
            attributes.contentDescription = session.contentPreview
            attributes.timestamp = session.createdAt
            attributes.keywords = displayTitle
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)

            return CSSearchableItem(
                uniqueIdentifier: session.spotlightUniqueIdentifier,
                domainIdentifier: EchoSession.spotlightDomainIdentifier,
                attributeSet: attributes
            )
        }

        guard !items.isEmpty else { return }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
        } catch {
            print("❌ Spotlight bulk indexing failed: \(error)")
        }
    }

    static func remove(session: EchoSession) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [session.spotlightUniqueIdentifier]
        ) { error in
            if let error {
                print("❌ Spotlight delete failed: \(error)")
            }
        }
    }
}
