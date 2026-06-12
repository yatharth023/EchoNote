//
//  SettingsView.swift
//  EchoNote
//

import SwiftUI

struct SettingsView: View {

    @Bindable var viewModel: LiveTranscriptViewModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

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
                        Text("Text Size: \(Int(settings.textSize))pt")
                            .font(.subheadline)
                        Slider(value: $settings.textSize, in: 14...40, step: 1)

                        Text("The quick brown fox jumps over the lazy dog.")
                            .font(.system(size: CGFloat(settings.textSize),
                                          weight: settings.highContrast ? .semibold : .regular))
                            .foregroundStyle(settings.transcriptForeground)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(settings.transcriptBackground,
                                        in: RoundedRectangle(cornerRadius: 8))
                    }

                    Toggle("High Contrast Mode", isOn: $settings.highContrast)

                    Toggle("Reduce Motion", isOn: $settings.reduceMotion)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-Scroll Speed")
                            .font(.subheadline)
                        Slider(value: $settings.autoScrollSpeed, in: 0.5...2.0, step: 0.25)
                        Text(settings.autoScrollSpeedLabel)
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
        .environment(AppSettings())
}
