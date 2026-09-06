//
//  VoiceCaptureStepView.swift
//  SiteVantage
//
//  Large press-and-hold push-to-talk button with a live level indicator.
//  On release, the on-device transcription result is shown immediately in
//  an editable text field — no blocking network call anywhere in this
//  screen (spec §4 screen 2).
//

import SwiftUI

struct VoiceCaptureStepView: View {
    @Bindable var ticket: FieldTicket
    let onNext: () -> Void

    @StateObject private var speechService = SpeechTranscriptionService()
    @State private var isPressing = false
    @State private var permissionState: PermissionState = .unknown
    @State private var editableText: String = ""

    /// DragGesture(minimumDistance: 0) rather than onLongPressGesture: it
    /// fires reliably on touch-down/touch-up (including release outside the
    /// button's bounds) with no minimum-duration edge cases, which matters
    /// for a push-to-talk control that must never get "stuck" recording.
    private var pushToTalkGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressing else { return }
                isPressing = true
                handlePressing(true)
            }
            .onEnded { _ in
                isPressing = false
                handlePressing(false)
            }
    }

    enum PermissionState {
        case unknown, authorized, denied
    }

    var body: some View {
        VStack(spacing: 24) {
            if permissionState == .denied {
                PermissionDeniedView(
                    iconName: "mic.slash",
                    title: "Microphone & Speech Access Needed",
                    message: "SiteVantage needs microphone and speech recognition access to capture the verbal scope on-device. No audio ever leaves this device."
                )
            } else {
                Spacer(minLength: 8)

                LevelWaveformView(level: speechService.audioLevel, isRecording: speechService.isRecording)
                    .frame(height: 60)
                    .padding(.horizontal, 32)

                PushToTalkButton(isRecording: speechService.isRecording)
                    .fieldTapTarget()
                    .gesture(pushToTalkGesture)

                Text(speechService.isRecording ? "Recording\u{2026} release to stop" : "Press and hold to describe the extra work")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let errorMessage = speechService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if !editableText.isEmpty || !speechService.isRecording {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcript (editable)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $editableText)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Button {
                    ticket.voiceRawText = editableText
                    ticket.voiceTranscriptionSource = .onDevice
                    onNext()
                } label: {
                    Text("Next: Review Scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .fieldTapTarget()
                .padding(.horizontal)
                .padding(.bottom)
                .disabled(editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            editableText = ticket.voiceRawText ?? ""
        }
        .onChange(of: speechService.transcript) { _, newValue in
            editableText = newValue
        }
        .onChange(of: speechService.permissionDenied) { _, denied in
            if denied { permissionState = .denied }
        }
    }

    private func handlePressing(_ pressing: Bool) {
        if pressing {
            Task {
                let result = await speechService.requestAuthorization()
                switch result {
                case .authorized:
                    permissionState = .authorized
                    speechService.startRecording()
                case .denied:
                    permissionState = .denied
                }
            }
        } else {
            speechService.stopRecording()
        }
    }
}

private struct PushToTalkButton: View {
    let isRecording: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isRecording ? Color.red : Color.accentColor)
                .frame(width: 140, height: 140)
                .shadow(radius: isRecording ? 12 : 4)
            Image(systemName: isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
        }
        .scaleEffect(isRecording ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isRecording)
    }
}

private struct LevelWaveformView: View {
    let level: Float
    let isRecording: Bool

    private let barCount = 24

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let phase = Double(index) / Double(barCount)
                    let magnitude = isRecording ? CGFloat(level) * (0.4 + 0.6 * sin(phase * .pi)) : 0.05
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isRecording ? Color.accentColor : Color(.systemGray4))
                        .frame(width: max(2, geometry.size.width / CGFloat(barCount) - 3),
                               height: max(4, geometry.size.height * max(0.08, magnitude)))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: level)
        }
    }
}
