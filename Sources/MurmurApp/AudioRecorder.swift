import AVFoundation
import Foundation

@MainActor
final class AudioRecorder {
    var onPowerChanged: ((Float) -> Void)?

    private var recorder: AVAudioRecorder?
    private var meteringTask: Task<Void, Never>?

    func start() async throws {
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
        guard granted else { throw MurmurError.microphoneDenied }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("murmur-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder.isMeteringEnabled = true
        guard audioRecorder.record() else { throw MurmurError.recordingFailed }
        recorder = audioRecorder
        meteringTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.updateMeters()
                do {
                    try await Task.sleep(for: .milliseconds(33))
                } catch {
                    return
                }
            }
        }
    }

    func stop() throws -> URL {
        stopMetering()
        guard let recorder else { throw MurmurError.recordingFailed }
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        return url
    }

    func cancel() {
        stopMetering()
        guard let recorder else { return }
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        try? FileManager.default.removeItem(at: url)
    }

    private func updateMeters() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        onPowerChanged?(recorder.averagePower(forChannel: 0))
    }

    private func stopMetering() {
        meteringTask?.cancel()
        meteringTask = nil
    }
}
