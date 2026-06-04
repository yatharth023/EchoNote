//
//  ModelManagementView.swift
//  EchoNote
//

import SwiftUI

struct ModelManagementView: View {

    @Bindable var viewModel: LiveTranscriptViewModel

    private let models: [WhisperModelInfo] = WhisperModelInfo.allModels
    private let deviceTier = DeviceCapabilityAnalyzer.analyze()

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "cpu")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device Recommendation")
                            .font(.headline)
                        Text(deviceTier.displayDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Available Models") {
                ForEach(models) { model in
                    let isActive = viewModel.activeModelId == model.id
                    let isBundled = viewModel.installedModelIds.contains(model.id)
                    ModelRowView(
                        model: model,
                        isRecommended: model.id == deviceTier.recommendedModelId,
                        isDownloading: false,
                        isActive: isActive,
                        isDownloaded: isBundled,
                        downloadProgress: 0
                    )
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("All processing happens on-device", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("No audio data ever leaves your iPhone", systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Models are stored locally", systemImage: "internaldrive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ModelRowView: View {

    let model: WhisperModelInfo
    let isRecommended: Bool
    let isDownloading: Bool
    var isActive: Bool = false
    var isDownloaded: Bool = false
    let downloadProgress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)
                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }

                    Text(model.accuracyTier.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if isDownloading {
                    ProgressView()
                } else if isDownloaded {
                    Label("Downloaded", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Label(model.formattedSize, systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("~\(model.estimatedLatencyMs)ms", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ModelManagementView(viewModel: LiveTranscriptViewModel())
    }
}
