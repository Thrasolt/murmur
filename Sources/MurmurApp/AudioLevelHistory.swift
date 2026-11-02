import Foundation

/// Recent microphone power, ordered from oldest to newest (about 0.7 seconds).
struct AudioLevelHistory {
    private(set) var levels = Array(repeating: Float.zero, count: 21)
    private var smoothedLevel: Float = 0

    mutating func append(power: Float) {
        // AVAudioRecorder reports dBFS. Gate quiet room noise and map the
        // useful speech range onto the display without amplifying each pause.
        let noiseFloor: Float = -50
        let speechCeiling: Float = -12
        let level = power.isFinite
            ? min(1, max(0, (power - noiseFloor) / (speechCeiling - noiseFloor)))
            : 0

        if level == 0 {
            smoothedLevel = 0
        } else {
            let response: Float = level > smoothedLevel ? 0.8 : 0.5
            smoothedLevel += (level - smoothedLevel) * response
        }
        levels.removeFirst()
        levels.append(smoothedLevel)
    }

    mutating func reset() {
        self = Self()
    }
}
