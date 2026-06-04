//
//  ModelSetupView.swift
//  EchoNote
//

import SwiftUI

struct ModelSetupView: View {

    @Bindable var viewModel: LiveTranscriptViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            headerSection

            featureList

            Spacer()

            downloadSection

            Spacer()
                .frame(height: 32)
        }
        .interactiveDismissDisabled(viewModel.modelState == .downloading || viewModel.modelState == .loading)
        .onChange(of: viewModel.modelState) { _, newState in
            if newState == .ready {
                onComplete()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "ear.and.waveform")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("Welcome to EchoNote")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Real-time speech transcription,\n100% on your device")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(spacing: 16) {
            featureRow(icon: "wifi.slash", text: "Fully offline — no internet needed ever")
            featureRow(icon: "lock.shield", text: "Private — audio never leaves your phone")
            featureRow(icon: "brain", text: "AI-powered — WhisperKit speech engine")
            featureRow(icon: "accessibility", text: "Accessible — designed for hearing-impaired users")
        }
        .padding(.horizontal)
    }

    private var downloadSection: some View {
        VStack(spacing: 16) {
            switch viewModel.modelState {
            case .notLoaded:
                downloadButton(title: "Get Started", disabled: false)

            case .downloading, .loading:
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Preparing speech engine...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                downloadButton(title: "Loading...", disabled: true)

            case .ready:
                Label("Ready!", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                downloadButton(title: "Get Started", disabled: false)

            case .error(let message):
                VStack(spacing: 8) {
                    Label("Setup failed", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                downloadButton(title: "Retry", disabled: false)
            }
        }
    }

    private func downloadButton(title: String, disabled: Bool) -> some View {
        Button {
            if viewModel.modelState == .ready {
                onComplete()
            } else {
                Task {
                    await viewModel.loadWhisperModel()
                }
            }
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    disabled ? Color.gray.opacity(0.3) : Color.blue,
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundColor(disabled ? .secondary : .white)
        }
        .disabled(disabled)
        .padding(.horizontal, 24)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

#Preview {
    ModelSetupView(viewModel: LiveTranscriptViewModel(), onComplete: {})
}
