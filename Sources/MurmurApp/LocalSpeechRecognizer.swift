import Foundation
import FluidAudio

@MainActor
final class LocalSpeechRecognizer {
    private var manager: AsrManager?
    private(set) var modelIsReady = false

    func prepare(allowDownload: Bool) async throws {
        guard manager == nil else { return }
        let modelDirectory = AsrModels.defaultCacheDirectory(for: .ultra)

        let models: AsrModels
        if AsrModels.modelsExist(at: modelDirectory) {
            ModelHub.offlineMode = true
            models = try await AsrModels.load(from: modelDirectory, version: .ultra)
        } else {
            guard allowDownload else { throw MurmurError.modelNotInstalled }
            ModelHub.offlineMode = false
            do {
                models = try await AsrModels.downloadAndLoad(to: modelDirectory, version: .ultra)
            } catch {
                ModelHub.offlineMode = true
                throw error
            }
            ModelHub.offlineMode = true
        }

        let asrManager = AsrManager(config: .default)
        try await asrManager.loadModels(models)
        manager = asrManager
        modelIsReady = true
    }

    func transcribe(_ url: URL) async throws -> String {
        guard let manager else { throw MurmurError.modelNotInstalled }
        ModelHub.offlineMode = true
        var decoderState = try TdtDecoderState()
        let result = try await manager.transcribe(url, decoderState: &decoderState)
        return result.text
    }
}
