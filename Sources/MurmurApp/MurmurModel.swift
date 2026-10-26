import AppKit
import ApplicationServices
import AVFoundation
import Combine
import Foundation

@MainActor
final class MurmurModel: ObservableObject {
    enum State: Equatable {
        case ready
        case starting
        case recording
        case processing
        case preview
        case error(String)
    }

    @Published private(set) var state: State = .ready
    @Published var transcript = ""
    @Published var polishText = true
    @Published private(set) var isModelReady = false
    @Published private(set) var isModelLoading = false

    var onShowOverlay: (() -> Void)?
    var onHideOverlay: (() -> Void)?

    private let recorder = AudioRecorder()
    private let recognizer = LocalSpeechRecognizer()
    private let hotkey = GlobalHotkey()
    private var targetApplication: NSRunningApplication?
    private var hotkeyError: String?
    private var hotkeyRegistered = false
    private var pendingStartID: UUID?
    private var shortcutIsDown = false
    private var recordingStartedByPushToTalk = false
    private var stopAfterMicrophoneStarts = false

    var isRecording: Bool { state == .recording }
    var menuTitle: String { isRecording ? "Aufnahme" : "Murmur" }

    init() {
        hotkey.onPress = { [weak self] in
            self?.pushToTalkPressed()
        }
        hotkey.onRelease = { [weak self] in
            self?.pushToTalkReleased()
        }
        Task { await loadCachedModel() }
    }

    func registerHotkeyIfNeeded() {
        guard !hotkeyRegistered, hotkeyError == nil else { return }
        do {
            try hotkey.register()
            hotkeyRegistered = true
        } catch {
            let message = "Der globale Shortcut konnte nicht registriert werden: \(error.localizedDescription)"
            hotkeyError = message
            state = .error(message)
        }
    }

    private func loadCachedModel() async {
        isModelLoading = true
        do {
            try await recognizer.prepare(allowDownload: false)
            isModelReady = true
            state = idleState
        } catch MurmurError.modelNotInstalled {
            state = idleState
        } catch {
            state = .error(error.localizedDescription)
        }
        isModelLoading = false
    }

    private var idleState: State {
        if let hotkeyError { return .error(hotkeyError) }
        return .ready
    }

    func toggleRecording() {
        switch state {
        case .recording:
            stopAndTranscribe()
        case .ready, .preview, .error:
            startRecording(fromPushToTalk: false)
        case .starting, .processing:
            break
        }
    }

    private func pushToTalkPressed() {
        guard !shortcutIsDown else { return }
        shortcutIsDown = true
        startRecording(fromPushToTalk: true)
    }

    private func pushToTalkReleased() {
        guard shortcutIsDown else { return }
        shortcutIsDown = false
        guard recordingStartedByPushToTalk else { return }

        if state == .starting {
            stopAfterMicrophoneStarts = true
        } else if state == .recording {
            stopAndTranscribe()
        }
    }

    private func startRecording(fromPushToTalk: Bool) {
        guard state != .starting, state != .recording, state != .processing, !isModelLoading else { return }
        transcript = ""
        targetApplication = NSWorkspace.shared.frontmostApplication
        let startID = UUID()
        pendingStartID = startID
        recordingStartedByPushToTalk = fromPushToTalk
        stopAfterMicrophoneStarts = false
        state = .starting
        onShowOverlay?()
        Task {
            do {
                try await recognizer.prepare(allowDownload: false)
                isModelReady = true
                try await recorder.start()
                guard pendingStartID == startID else {
                    recorder.cancel()
                    return
                }
                pendingStartID = nil
                state = .recording
                if stopAfterMicrophoneStarts || (recordingStartedByPushToTalk && !shortcutIsDown) {
                    stopAndTranscribe()
                }
            } catch {
                guard pendingStartID == startID else { return }
                pendingStartID = nil
                recordingStartedByPushToTalk = false
                stopAfterMicrophoneStarts = false
                state = .error(error.localizedDescription)
            }
        }
    }

    func installModel() {
        guard !isModelLoading else { return }
        isModelLoading = true
        state = .processing
        Task {
            do {
                try await recognizer.prepare(allowDownload: true)
                isModelReady = true
                state = idleState
            } catch {
                state = .error(error.localizedDescription)
            }
            isModelLoading = false
        }
    }

    func stopAndTranscribe() {
        guard state == .recording else { return }
        recordingStartedByPushToTalk = false
        stopAfterMicrophoneStarts = false
        state = .processing
        Task {
            do {
                let audioURL = try recorder.stop()
                defer { try? FileManager.default.removeItem(at: audioURL) }
                let recognized = try await recognizer.transcribe(audioURL)
                transcript = polishText ? Self.polish(recognized) : recognized
                guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw MurmurError.emptyTranscript
                }
                let inserted = await insertIntoPreviousApp(transcript)
                state = .preview
                if inserted {
                    onHideOverlay?()
                    state = idleState
                } else {
                    onShowOverlay?()
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func cancel() {
        pendingStartID = nil
        recordingStartedByPushToTalk = false
        stopAfterMicrophoneStarts = false
        shortcutIsDown = false
        recorder.cancel()
        transcript = ""
        state = idleState
        onHideOverlay?()
    }

    func copyTranscript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
    }

    func retryInsert() {
        Task {
            let inserted = await insertIntoPreviousApp(transcript)
            if inserted {
                state = idleState
                onHideOverlay?()
            }
        }
    }

    private func insertIntoPreviousApp(_ text: String) async -> Bool {
        guard let targetApplication, targetApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return false
        }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return false }

        let pasteboard = NSPasteboard.general
        let previous = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var values: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { values[type] = data }
            }
            return values.isEmpty ? nil : values
        } ?? []

        targetApplication.activate()
        try? await Task.sleep(for: .milliseconds(250))
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        if let source = CGEventSource(stateID: .combinedSessionState),
           let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
           let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        } else {
            restorePasteboard(previous, pasteboard: pasteboard)
            return false
        }
        try? await Task.sleep(for: .milliseconds(700))
        restorePasteboard(previous, pasteboard: pasteboard)
        return true
    }

    private func restorePasteboard(_ items: [[NSPasteboard.PasteboardType: Data]], pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(restored)
    }

    private static func polish(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = normalized.first else { return normalized }
        let capitalized = String(first).uppercased() + normalized.dropFirst()
        if let last = capitalized.last, ".!?…".contains(last) { return capitalized }
        return capitalized + "."
    }
}

enum MurmurError: LocalizedError {
    case microphoneDenied
    case recordingFailed
    case modelNotInstalled
    case recognitionFailed
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Murmur benötigt Mikrofonzugriff. Erlaube ihn in den Systemeinstellungen unter Datenschutz & Sicherheit → Mikrofon."
        case .recordingFailed:
            return "Die Aufnahme konnte nicht gestartet werden."
        case .modelNotInstalled:
            return "Das lokale Sprachmodell ist noch nicht eingerichtet. Lade es zuerst in Murmur herunter."
        case .recognitionFailed:
            return "Die lokale Spracherkennung ist fehlgeschlagen."
        case .emptyTranscript:
            return "Es wurde kein verständlicher Text erkannt."
        }
    }
}
