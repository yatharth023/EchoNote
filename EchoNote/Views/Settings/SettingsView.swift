//
//  SettingsView.swift
//  EchoNote
//

import SwiftUI

struct SettingsView: View {

    @Bindable var viewModel: LiveTranscriptViewModel

    @State private var selectedTextSize: Double = 17
    @State private var highContrastEnabled: Bool = false
    @State private var reducedMotion: Bool = false
    @State private var autoScrollSpeed: Double = 1.0

    var body: some View {
        NavigationStack {
            List {
                Section("Speech Model") {
                    NavigationLink(destination: ModelManagementView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text("Model Management")
                                Text("Download, switch, or delete models")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Accessibility") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text Size: \(Int(selectedTextSize))pt")
                            .font(.subheadline)
                        Slider(value: $selectedTextSize, in: 14...40, step: 1)
                    }

                    Toggle("High Contrast Mode", isOn: $highContrastEnabled)

                    Toggle("Reduce Motion", isOn: $reducedMotion)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-Scroll Speed")
                            .font(.subheadline)
                        Slider(value: $autoScrollSpeed, in: 0.5...2.0, step: 0.25)
                        Text(autoScrollSpeed == 1.0 ? "Normal" : String(format: "%.2fx", autoScrollSpeed))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("WhisperKit (On-Device)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Privacy")
                        Spacer()
                        Text("100% Offline")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(viewModel: LiveTranscriptViewModel())
}
