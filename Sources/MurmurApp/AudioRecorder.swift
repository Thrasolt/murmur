import AVFoundation
import Foundation

@MainActor
final class AudioRecorder {
    private var recorder: AVAudioRecorder?

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
        guard audioRecorder.record() else { throw MurmurError.recordingFailed }
        recorder = audioRecorder
    }

    func stop() throws -> URL {
        guard let recorder else { throw MurmurError.recordingFailed }
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        return url
    }

    func cancel() {
        guard let recorder else { return }
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        try? FileManager.default.removeItem(at: url)
    }
}
