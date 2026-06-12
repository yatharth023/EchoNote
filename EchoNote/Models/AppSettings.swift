//
//  AppSettings.swift
//  EchoNote
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class AppSettings {

    static let textSizeKey = "echoNote.textSize"
    static let highContrastKey = "echoNote.highContrast"
    static let reduceMotionKey = "echoNote.reduceMotion"
    static let autoScrollSpeedKey = "echoNote.autoScrollSpeed"

    var textSize: Double {
        didSet { UserDefaults.standard.set(textSize, forKey: Self.textSizeKey) }
    }

    var highContrast: Bool {
        didSet { UserDefaults.standard.set(highContrast, forKey: Self.highContrastKey) }
    }

    var reduceMotion: Bool {
        didSet { UserDefaults.standard.set(reduceMotion, forKey: Self.reduceMotionKey) }
    }

    var autoScrollSpeed: Double {
        didSet { UserDefaults.standard.set(autoScrollSpeed, forKey: Self.autoScrollSpeedKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        self.textSize = defaults.object(forKey: Self.textSizeKey) as? Double ?? 17
        self.highContrast = defaults.bool(forKey: Self.highContrastKey)
        self.reduceMotion = defaults.bool(forKey: Self.reduceMotionKey)
        self.autoScrollSpeed = defaults.object(forKey: Self.autoScrollSpeedKey) as? Double ?? 1.0
    }

    var transcriptFont: Font {
        let weight: Font.Weight = highContrast ? .semibold : .regular
        return .system(size: CGFloat(textSize), weight: weight)
    }

    var transcriptForeground: Color {
        highContrast ? .black : .primary
    }

    var transcriptBackground: Color {
        highContrast ? Color.yellow.opacity(0.18) : Color.clear
    }

    var scrollAnimation: Animation? {
        guard !reduceMotion else { return nil }
        // Higher speed -> shorter duration
        let duration = max(0.05, 0.4 / autoScrollSpeed)
        return .easeOut(duration: duration)
    }

    var standardAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.25)
    }

    var autoScrollSpeedLabel: String {
        autoScrollSpeed == 1.0 ? "Normal" : String(format: "%.2fx", autoScrollSpeed)
    }
}
