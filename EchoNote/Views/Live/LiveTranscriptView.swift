//
//  LiveTranscriptView.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 03/06/26.
//

import SwiftUI
import SwiftData

struct LiveTranscriptView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LiveTranscriptViewModel()
    @State private var scrollViewID = UUID()

    private let bottomAnchorID = "bottom-anchor"

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                transcriptScrollView

                if viewModel.showSnapToLiveButton {
                    snapToLiveButton
                }
            }
            .navigationTitle("Live Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    highlightModeMenu
                }

                ToolbarItem(placement: .primaryAction) {
                    recordButton
                }
            }
            .alert("Permission Error", isPresented: showErrorAlert) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                viewModel.setModelContext(modelContext)
            }
            .onChange(of: viewModel.selectedHighlightMode) { _, _ in
                Task {
                    await viewModel.reprocessWithCurrentHighlightMode()
                }
            }
        }
    }

    private var transcriptScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.transcriptText.characters.isEmpty {
                        emptyStateView
                    } else {
                        Text(viewModel.transcriptText)
                            .font(.body)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .onChange(of: viewModel.transcriptText) { _, _ in
                if viewModel.isAutoScrollEnabled {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture().onChanged { value in
                    if value.translation.height > 10 {
                        viewModel.disableAutoScroll()
                    }
                }
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            if viewModel.isRecording {
                audioWaveformVisualizer
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.isRecording
                ? "Listening..."
                : "Tap the microphone to start recording")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        .padding()
    }

    private var audioWaveformVisualizer: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<9, id: \.self) { index in
                Capsule()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 5, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: viewModel.currentAudioLevel)
            }
        }
        .frame(height: 80)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8.0
        let maxHeight: CGFloat = 70.0
        let level = CGFloat(viewModel.currentAudioLevel)

        // Create symmetric waveform shape: center bars taller
        let centerDistance = abs(CGFloat(index) - 4.0) / 4.0
        let heightMultiplier = 1.0 - (centerDistance * 0.5)

        // Scale by audio level
        let dynamicHeight = baseHeight + (maxHeight - baseHeight) * level * heightMultiplier

        return max(baseHeight, dynamicHeight)
    }

    private var highlightModeMenu: some View {
        Menu {
            Picker("Highlight Mode", selection: $viewModel.selectedHighlightMode) {
                ForEach(HighlightMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Highlights", systemImage: viewModel.selectedHighlightMode.icon)
                .labelStyle(.iconOnly)
                .font(.title3)
        }
        .accessibilityLabel("Change highlight mode")
    }

    private var recordButton: some View {
        Button {
            Task {
                if viewModel.isRecording {
                    await viewModel.stopRecording()
                } else {
                    await viewModel.startRecording()
                }
            }
        } label: {
            Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.title)
                .foregroundStyle(viewModel.isRecording ? .red : .blue)
        }
        .accessibilityLabel(viewModel.isRecording ? "Stop Recording" : "Start Recording")
    }

    private var snapToLiveButton: some View {
        Button {
            viewModel.enableAutoScroll()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Snap to Live Voice")
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityLabel("Scroll to latest transcript")
    }

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    LiveTranscriptView()
}
