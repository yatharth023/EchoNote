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
                    let isDownloaded = viewModel.installedModelIds.contains(model.id)
                    let isDownloading = viewModel.downloadingModelId == model.id
                    let isActivating = isActive && viewModel.modelState == .loading
                    ModelRowView(
                        model: model,
                        isRecommended: model.id == deviceTier.recommendedModelId,
                        isDownloading: isDownloading,
                        isActive: isActive,
                        isDownloaded: isDownloaded,
                        isActivating: isActivating,
                        downloadProgress: isDownloading ? viewModel.downloadProgress : 0,
                        onDownload: {
                            Task { await viewModel.downloadAndActivateModel(model.id) }
                        },
                        onActivate: {
                            Task { await viewModel.activateModel(model.id) }
                        }
                    )
                    .animation(.easeInOut(duration: 0.2), value: isActive)
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
    var isActivating: Bool = false
    var downloadProgress: Double = 0
    var onDownload: (() -> Void)?
    var onActivate: (() -> Void)?

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
                    HStack(spacing: 6) {
                        if isActivating {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                            .transition(.scale.combined(with: .opacity))
                    }
                } else if isDownloading {
                    CircularDownloadProgress(progress: downloadProgress)
                        .frame(width: 28, height: 28)
                } else if isDownloaded {
                    Button("Activate") {
                        onActivate?()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button {
                        onDownload?()
                    } label: {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.title3)
                    }
                }
            }

            HStack(spacing: 16) {
                Label(model.formattedSize, systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("~\(model.estimatedLatencyMs)ms", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isDownloading {
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CircularDownloadProgress: View {

    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)

            Image(systemName: "stop.fill")
                .font(.system(size: 8))
                .foregroundStyle(.blue)
        }
    }
}

#Preview {
    NavigationStack {
        ModelManagementView(viewModel: LiveTranscriptViewModel())
    }
}
