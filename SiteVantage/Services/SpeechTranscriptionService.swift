//
//  SpeechTranscriptionService.swift
//  SiteVantage
//
//  Push-to-talk, fully on-device transcription via SFSpeechRecognizer with
//  requiresOnDeviceRecognition = true. No network call is ever made by this
//  service — that's what lets the voice capture step work with the device
//  in Airplane Mode, per spec §5/§6. There is no cloud-refinement pass in
//  this build.
//

import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
final class SpeechTranscriptionService: NSObject, ObservableObject {
    @Published private(set) var transcript: String = ""
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var permissionDenied: Bool = false
    @Published private(set) var onDeviceUnavailable: Bool = false
    @Published private(set) var errorMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    enum AuthorizationResult {
        case authorized
        case denied
    }

    func requestAuthorization() async -> AuthorizationResult {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            permissionDenied = true
            return .denied
        }

        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else {
            permissionDenied = true
            return .denied
        }

        permissionDenied = false
        return .authorized
    }

    func startRecording() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is unavailable on this device."
            return
        }
        guard speechRecognizer.supportsOnDeviceRecognition else {
            onDeviceUnavailable = true
            errorMessage = "On-device transcription isn't available on this device/OS. This app never falls back to cloud transcription."
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""
        errorMessage = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Could not start the audio session: \(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            self?.updateLevel(from: buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Could not start the audio engine: \(error.localizedDescription)"
            return
        }

        isRecording = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.teardownAudio()
                }
            }
        }
    }

    func stopRecording() {
        recognitionRequest?.endAudio()
        teardownAudio()
    }

    private func teardownAudio() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRecording = false
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private nonisolated func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        var sum: Float = 0
        let samples = channelData[0]
        for index in 0..<frameLength {
            let sample = samples[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        let normalized = min(max(rms * 20, 0), 1)
        Task { @MainActor [weak self] in
            self?.audioLevel = normalized
        }
    }

    func reset() {
        transcript = ""
        errorMessage = nil
    }
}
