import AppKit
import SwiftUI

private enum MurmurStyle {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.09)
    static let card = Color(red: 0.075, green: 0.105, blue: 0.15)
    static let muted = Color(red: 0.57, green: 0.64, blue: 0.73)
    static let mint = Color(red: 0.42, green: 0.94, blue: 0.76)
    static let blue = Color(red: 0.35, green: 0.72, blue: 1.0)
}

struct MenuContent: View {
    @ObservedObject var model: MurmurModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            hero

            if !model.isModelReady {
                modelSetup
            }

            if !model.transcript.isEmpty {
                transcriptCard
            }

            footer
        }
        .padding(20)
        .frame(width: 382)
        .foregroundStyle(.white)
        .background {
            ZStack(alignment: .topTrailing) {
                MurmurStyle.background
                Circle()
                    .fill(MurmurStyle.blue.opacity(0.18))
                    .frame(width: 190, height: 190)
                    .blur(radius: 70)
                    .offset(x: 70, y: -80)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [MurmurStyle.mint, MurmurStyle.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                Image(systemName: "waveform")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(MurmurStyle.background)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Murmur")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("LOKALES SPRACHINPUT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(MurmurStyle.muted)
            }

            Spacer()

            statusBadge
        }
    }

    private var statusBadge: some View {
        let active = model.isRecording
        return HStack(spacing: 6) {
            Circle()
                .fill(active ? MurmurStyle.mint : (model.isModelReady ? MurmurStyle.blue : Color.orange))
                .frame(width: 6, height: 6)
            Text(active ? "HÖRT ZU" : (model.isModelReady ? "BEREIT" : "EINRICHTEN"))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
        }
        .foregroundStyle(active ? MurmurStyle.mint : MurmurStyle.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.055), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private var hero: some View {
        VStack(spacing: 14) {
            WaveformView(isActive: model.isRecording || model.state == .starting)
                .frame(height: 42)

            VStack(spacing: 5) {
                Text(heroTitle)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(heroSubtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(MurmurStyle.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            HStack(spacing: 7) {
                Keycap(title: "⌥")
                Text("+").font(.system(size: 12, weight: .medium)).foregroundStyle(MurmurStyle.muted)
                Keycap(title: "Leertaste", wide: true)
                Text("halten").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(MurmurStyle.muted)
            }
            .padding(.top, 2)

            Button {
                model.toggleRecording()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(model.isRecording ? "Aufnahme beenden" : "Aufnahme manuell starten")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(model.isModelLoading || model.state == .starting || model.state == .processing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [MurmurStyle.card, MurmurStyle.card.opacity(0.74)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
        }
    }

    private var modelSetup: some View {
        HStack(spacing: 11) {
            Image(systemName: model.isModelLoading ? "arrow.triangle.2.circlepath" : "cpu")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MurmurStyle.mint)
                .frame(width: 34, height: 34)
                .background(MurmurStyle.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(model.isModelLoading ? "Modell wird vorbereitet" : "Parakeet Ultra")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(model.isModelLoading ? "Bleibt vollständig auf diesem Mac" : "Einmalig lokal installieren · ca. 630 MB")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(MurmurStyle.muted)
            }

            Spacer(minLength: 4)

            if !model.isModelLoading {
                Button("Installieren") { model.installModel() }
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .buttonStyle(.plain)
                    .foregroundStyle(MurmurStyle.mint)
            }
        }
        .padding(11)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.state == .preview ? "NOCH NICHT EINGEFÜGT" : "TRANSKRIPT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(MurmurStyle.muted)
                Spacer()
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MurmurStyle.muted)
            }

            TextEditor(text: $model.transcript)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .scrollContentBackground(.hidden)
                .frame(height: 72)
                .padding(7)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            HStack(spacing: 8) {
                Button { model.copyTranscript() } label: {
                    Label("Kopieren", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())

                Button { model.retryInsert() } label: {
                    Label("Erneut einfügen", systemImage: "arrow.uturn.forward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(MurmurStyle.mint.opacity(0.9))
            Text("Audio und Text bleiben lokal")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(MurmurStyle.muted)
            Spacer(minLength: 0)
            Toggle("Glätten", isOn: $model.polishText)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tint(MurmurStyle.mint)
        }
        .padding(.horizontal, 2)
    }

    private var heroTitle: String {
        switch model.state {
        case .ready: return "Deine Stimme, direkt im Textfeld"
        case .starting: return "Mikrofon wird gestartet"
        case .recording: return "Ich höre dir zu"
        case .processing: return "Wird lokal verarbeitet"
        case .preview: return "Text liegt für dich bereit"
        case .error: return "Murmur braucht kurz Hilfe"
        }
    }

    private var heroSubtitle: String {
        switch model.state {
        case .ready: return "Halte ⌥ Leertaste gedrückt und sprich los."
        case .starting: return "Sobald das Mikrofon bereit ist, geht es los."
        case .recording: return "Lass die Tasten los, um zu transkribieren und einzufügen."
        case .processing: return "Dein Diktat verlässt diesen Mac nicht."
        case .preview: return "Prüfe den Text oder füge ihn erneut ein."
        case .error(let message): return message
        }
    }
}

struct OverlayContent: View {
    @ObservedObject var model: MurmurModel

    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 7) {
                Image(systemName: model.isRecording ? "waveform" : "waveform.circle.fill")
                    .foregroundStyle(MurmurStyle.mint)
                Text(model.isRecording ? "MURMUR HÖRT ZU" : "MURMUR")
                    .tracking(1.2)
                    .foregroundStyle(MurmurStyle.muted)
                Spacer()
                Circle().fill(model.isRecording ? MurmurStyle.mint : MurmurStyle.blue).frame(width: 7, height: 7)
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))

            WaveformView(isActive: model.isRecording || model.state == .starting)
                .frame(height: 36)

            Text(overlayTitle)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            if !model.transcript.isEmpty {
                TextEditor(text: $model.transcript)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .frame(height: 55)
                    .padding(6)
                    .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                HStack(spacing: 8) {
                    Button("Kopieren") { model.copyTranscript() }.buttonStyle(SoftButtonStyle())
                    Button("Erneut einfügen") { model.retryInsert() }.buttonStyle(AccentButtonStyle())
                }
            }

            HStack(spacing: 9) {
                if model.isRecording {
                    Button("Jetzt stoppen") { model.stopAndTranscribe() }.buttonStyle(AccentButtonStyle())
                }
                Button("Abbrechen") { model.cancel() }.buttonStyle(SoftButtonStyle())
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))

            Text("Lokal verarbeitet · ⌥ Leertaste loslassen zum Beenden")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(MurmurStyle.muted)
        }
        .padding(20)
        .frame(width: 410, height: model.transcript.isEmpty ? 238 : 320)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.07, green: 0.11, blue: 0.16), MurmurStyle.background], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(LinearGradient(colors: [MurmurStyle.mint.opacity(0.35), Color.white.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
        }
        .preferredColorScheme(.dark)
    }

    private var overlayTitle: String {
        switch model.state {
        case .ready: return "Bereit für dein Diktat"
        case .starting: return "Mikrofon startet …"
        case .recording: return "Lass ⌥ Leertaste los, wenn du fertig bist"
        case .processing: return "Dein Text entsteht gerade …"
        case .preview: return "Text konnte nicht eingefügt werden"
        case .error(let message): return message
        }
    }
}

private struct Keycap: View {
    let title: String
    var wide = false

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.88))
            .padding(.horizontal, wide ? 10 : 8)
            .frame(height: 25)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

private struct WaveformView: View {
    let isActive: Bool
    private let levels: [CGFloat] = [0.18, 0.30, 0.22, 0.55, 0.34, 0.75, 0.40, 0.25, 0.66, 0.31, 0.86, 0.44, 0.27, 0.63, 0.35, 0.72, 0.30, 0.55, 0.24, 0.43, 0.20]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isActive)) { timeline in
            HStack(spacing: 4) {
                ForEach(levels.indices, id: \.self) { index in
                    let phase = timeline.date.timeIntervalSinceReferenceDate * 5.0 + Double(index) * 0.72
                    let animatedLevel = 0.14 + 0.86 * abs(sin(phase))
                    let level = isActive ? animatedLevel : Double(levels[index])
                    Capsule()
                        .fill(LinearGradient(colors: [MurmurStyle.mint, MurmurStyle.blue], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: max(5, CGFloat(level) * 36))
                        .opacity(isActive ? 0.96 : 0.62)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
    }
}

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(MurmurStyle.background)
            .background(LinearGradient(colors: [MurmurStyle.mint, Color(red: 0.55, green: 0.83, blue: 1.0)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

private struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(0.86))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.065), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .animation(.easeOut(duration: 0.13), value: configuration.isPressed)
    }
}
