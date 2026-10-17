import AppKit
import CoreGraphics
import Foundation
import GoodnessRobloxClientCore
import SwiftUI

@MainActor
final class RhythmAutoPlayerViewModel: ObservableObject {
    @Published private(set) var instrument: RhythmInstrument = .drums
    @Published private(set) var lanes: [RhythmLane] = RhythmInstrument.drums.defaultLanes
    @Published private(set) var captureOptions: [RhythmCaptureOption] = []
    @Published var selectedSourceID = ""

    @Published var hueDegrees = 307.0
    @Published var detectionMode: RhythmNoteDetectionMode = .hybrid
    @Published var hueTolerance = 34.0
    @Published var minimumSaturation = 0.44
    @Published var leadPixels = 12.0
    @Published var keyHoldMilliseconds = 70.0
    @Published var autoCalibrateOnStart = true

    @Published private(set) var previewImage: CGImage?
    @Published private(set) var calibrationIndex: Int?
    @Published private(set) var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var isDiscovering = false
    @Published private(set) var statusMessage = "Escolha uma janela do Roblox ou a tela e calibre as teclas."
    @Published private(set) var visibleNotes = 0
    @Published private(set) var hits = 0
    @Published private(set) var capturedUpdates = 0
    @Published private(set) var lastKeysPressed = "-"
    @Published private(set) var robloxFocused = false
    @Published private(set) var isCalibratingAutomatically = false
    @Published private(set) var isTestingKeys = false
    @Published private(set) var keyboardAuthorized = KeyboardSimulator.shared.hasAccessibilityPermission

    private let capture = RhythmCaptureService()
    private var sessionID = UUID()

    init() {
        lanes = loadLanes(for: .drums)
    }

    var calibrationInstruction: String {
        guard let index = calibrationIndex, lanes.indices.contains(index) else {
            return "Clique em Calibrar e marque o centro de cada tecla no vídeo."
        }
        return "Clique no centro de \(lanes[index].key.uppercased()) (\(index + 1)/\(lanes.count))."
    }

    var settings: RhythmVisionSettings {
        RhythmVisionSettings(
            hueDegrees: hueDegrees,
            toleranceDegrees: hueTolerance,
            minimumSaturation: minimumSaturation,
            scanDepth: 0.30,
            leadPixels: leadPixels,
            detectionMode: detectionMode
        )
    }

    func refreshSources() {
        guard !isDiscovering, !isStarting else { return }
        isDiscovering = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let options = try await capture.discoverSources()
                captureOptions = options
                if !options.contains(where: { $0.id == self.selectedSourceID }) {
                    selectedSourceID = options.first?.id ?? ""
                }
                statusMessage = options.isEmpty
                    ? "Nenhuma tela encontrada. Autorize a Gravação da Tela no macOS."
                    : "Fonte encontrada. Calibre as teclas e clique em Iniciar."
            } catch {
                statusMessage = "Captura indisponível: \(error.localizedDescription). Verifique Gravação da Tela."
            }
            isDiscovering = false
        }
    }

    func chooseInstrument(_ choice: RhythmInstrument) {
        guard !isRunning, !isStarting else { return }
        instrument = choice
        lanes = loadLanes(for: choice)
        calibrationIndex = nil
        previewImage = nil
        statusMessage = "Modo \(choice.title) selecionado. Calibre as teclas."
        applySettings()
    }

    func startCalibration() {
        guard !lanes.isEmpty else { return }
        calibrationIndex = 0
        statusMessage = calibrationInstruction
    }

    func autoCalibrate() {
        guard isRunning, !isCalibratingAutomatically else {
            if !isRunning {
                statusMessage = "Inicie a captura antes de procurar os receptores automaticamente."
            }
            return
        }
        isCalibratingAutomatically = true
        calibrationIndex = nil
        statusMessage = "Procurando os círculos dos receptores na captura..."

        let expectedKeys = lanes.map(\.key)
        let currentSession = sessionID
        capture.locateReceivers(keys: expectedKeys) { [weak self] found in
            Task { @MainActor [weak self] in
                guard let self, self.sessionID == currentSession else { return }
                self.isCalibratingAutomatically = false
                if let found, found.count == expectedKeys.count {
                    self.lanes = found
                    self.saveLanes()
                    self.applySettings()
                    self.statusMessage = "\(found.count) receptores localizados! Foque o Roblox e teste uma música."
                } else {
                    self.statusMessage = "Não encontrei o grupo de círculos. Use Calibrar e marque X/C/N/M ou F/J manualmente."
                }
            }
        }
    }

    func testKeysAfterDelay() {
        guard !isTestingKeys else { return }
        keyboardAuthorized = KeyboardSimulator.shared.hasAccessibilityPermission
        guard keyboardAuthorized else {
            statusMessage = "Autorize Acessibilidade para testar as teclas."
            return
        }
        isTestingKeys = true
        statusMessage = "Teste de teclado em 3 segundos. Clique na janela do Roblox agora."
        let expectedKeys = lanes.map(\.key)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                for key in expectedKeys {
                    try Task.checkCancellation()
                    let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
                    guard name.localizedCaseInsensitiveContains("Roblox") else {
                        statusMessage = "Teste não enviado: Roblox não estava em primeiro plano."
                        isTestingKeys = false
                        return
                    }
                    try await KeyboardSimulator.shared.pressChord([key], holdDuration: 0.085)
                    lastKeysPressed = String(key).uppercased()
                    try await Task.sleep(nanoseconds: 220_000_000)
                }
                statusMessage = "Teste concluído: \(expectedKeys.map { String($0).uppercased() }.joined(separator: ", "))."
            } catch {
                statusMessage = "Teste falhou: \(error.localizedDescription)"
            }
            isTestingKeys = false
        }
    }

    func cancelCalibration() {
        calibrationIndex = nil
    }

    func calibrate(x: Double, y: Double) {
        guard let index = calibrationIndex, lanes.indices.contains(index) else { return }
        lanes[index].x = max(0.03, min(0.97, x))
        lanes[index].y = max(0.03, min(0.97, y))
        saveLanes()
        if index + 1 < lanes.count {
            calibrationIndex = index + 1
            statusMessage = calibrationInstruction
        } else {
            calibrationIndex = nil
            statusMessage = "Calibração salva para \(instrument.title)."
        }
        applySettings()
    }

    func applySettings() {
        capture.update(lanes: lanes, settings: settings)
    }

    func requestKeyboardPermission() {
        KeyboardSimulator.shared.requestAccessibilityPermission()
        KeyboardSimulator.shared.openAccessibilitySettings()
        keyboardAuthorized = KeyboardSimulator.shared.hasAccessibilityPermission
    }

    func requestScreenPermission() {
        _ = CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func start() {
        guard !isRunning, !isStarting else { return }
        keyboardAuthorized = KeyboardSimulator.shared.hasAccessibilityPermission
        guard keyboardAuthorized else {
            statusMessage = "Autorize Acessibilidade para enviar as teclas."
            requestKeyboardPermission()
            return
        }
        guard !selectedSourceID.isEmpty else {
            statusMessage = "Selecione a janela do Roblox ou a tela."
            return
        }

        isStarting = true
        let currentSession = UUID()
        sessionID = currentSession
        let sourceID = selectedSourceID
        hits = 0
        visibleNotes = 0
        capturedUpdates = 0
        lastKeysPressed = "-"
        robloxFocused = false
        statusMessage = "Iniciando captura de vídeo..."

        Task { [weak self] in
            guard let self else { return }
            do {
                try await capture.start(
                    sourceID: sourceID,
                    lanes: lanes,
                    settings: settings,
                    onPreview: { [weak self] image in
                        Task { @MainActor [weak self] in
                            guard let self, self.sessionID == currentSession else { return }
                            self.previewImage = image
                        }
                    },
                    onKeys: { [weak self] keys in
                        Task { @MainActor [weak self] in
                            guard let self, self.sessionID == currentSession else { return }
                            self.perform(keys: keys)
                        }
                    },
                    onNoteCount: { [weak self] count in
                        Task { @MainActor [weak self] in
                            guard let self, self.sessionID == currentSession else { return }
                            self.visibleNotes = count
                            self.capturedUpdates += 1
                            self.robloxFocused = (
                                NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
                            ).localizedCaseInsensitiveContains("Roblox")
                        }
                    }
                )
                guard sessionID == currentSession else {
                    await capture.stop()
                    return
                }
                isRunning = true
                statusMessage = "Capturando. Foque o Roblox para tocar."
                if autoCalibrateOnStart {
                    autoCalibrate()
                }
            } catch {
                if sessionID == currentSession {
                    statusMessage = "Falha ao capturar: \(error.localizedDescription)"
                }
            }
            if sessionID == currentSession { isStarting = false }
        }
    }

    func stop() {
        guard isRunning || isStarting else { return }
        sessionID = UUID()
        isRunning = false
        isStarting = false
        isCalibratingAutomatically = false
        calibrationIndex = nil
        visibleNotes = 0
        statusMessage = "Parado."
        Task { [capture] in
            await capture.stop()
        }
    }

    private func perform(keys: [Character]) {
        guard isRunning else { return }
        // Segurança: nunca emitir teclas se outro aplicativo estiver em primeiro plano.
        let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        guard frontmost.localizedCaseInsensitiveContains("Roblox") else {
            statusMessage = "Capturando, mas aguardando você focar a janela do Roblox."
            return
        }

        hits += keys.count
        lastKeysPressed = keys.map { String($0).uppercased() }.joined(separator: "+")
        statusMessage = "Notas acionadas: \(hits) (última tecla: \(lastKeysPressed))."
        let hold = max(0.015, min(0.20, keyHoldMilliseconds / 1000))
        Task {
            do {
                try await KeyboardSimulator.shared.pressChord(keys, holdDuration: hold)
            } catch {
                statusMessage = "Erro de teclado: \(error.localizedDescription)"
            }
        }
    }

    private func defaultsKey(for instrument: RhythmInstrument) -> String {
        "goodness.rhythm.calibration.\(instrument.rawValue)"
    }

    private func saveLanes() {
        if let data = try? JSONEncoder().encode(lanes) {
            UserDefaults.standard.set(data, forKey: defaultsKey(for: instrument))
        }
    }

    private func loadLanes(for instrument: RhythmInstrument) -> [RhythmLane] {
        if let data = UserDefaults.standard.data(forKey: defaultsKey(for: instrument)),
           let lanes = try? JSONDecoder().decode([RhythmLane].self, from: data),
           lanes.count == instrument.defaultLanes.count {
            return lanes
        }
        return instrument.defaultLanes
    }
}
