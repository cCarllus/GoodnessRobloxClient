import Foundation
import GoodnessRobloxClientCore
import SwiftUI

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var sheetText = """
    [6] [6] [6] [6]
    [7] [6] [6] [18]
    [6psu] 6 6 [6dy] [%aOuy] % % [%st]
    [6eptu] 6 6 6 6 [6p]O[6p]a[6s]d
    """

    @Published var tempoMilliseconds = 140.0
    @Published var holdPercentage = 62.0
    @Published var startDelaySeconds = 5.0
    @Published var whitespaceCreatesRests = true
    @Published var newlineRestUnits = 2.0

    @Published private(set) var parsedEvents: [PianoSheetEvent] = []
    @Published private(set) var currentEventIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isPaused = false
    @Published private(set) var statusMessage = "Pronto"
    @Published private(set) var permissionGranted = KeyboardSimulator.shared.hasAccessibilityPermission

    private var playbackTask: Task<Void, Never>?

    var progressValue: Double {
        guard !parsedEvents.isEmpty else { return 0 }
        return Double(currentEventIndex) / Double(parsedEvents.count)
    }

    var supportedEventCount: Int {
        parsedEvents.filter {
            if case .chord = $0.kind { return true }
            return false
        }.count
    }

    func refreshPermissionStatus() {
        permissionGranted = KeyboardSimulator.shared.hasAccessibilityPermission
    }

    func requestPermission() {
        KeyboardSimulator.shared.requestAccessibilityPermission()
        KeyboardSimulator.shared.openAccessibilitySettings()
        refreshPermissionStatus()
        statusMessage = "Autorize o app em Ajustes do Sistema > Privacidade e Seguranca > Acessibilidade."
    }

    func parseSheet() {
        let options = PianoSheetParserOptions(
            whitespaceCreatesRests: whitespaceCreatesRests,
            newlineRestUnits: Int(newlineRestUnits),
            tabRestUnits: 2
        )
        parsedEvents = PianoSheetParser.parse(sheetText, options: options)
        currentEventIndex = 0
        statusMessage = parsedEvents.isEmpty ? "Nenhum evento encontrado na sheet." : "\(parsedEvents.count) eventos preparados."
    }

    func play() {
        refreshPermissionStatus()
        guard permissionGranted else {
            requestPermission()
            return
        }

        if isPaused {
            isPaused = false
            statusMessage = "Reproduzindo"
            return
        }

        parseSheet()
        guard !parsedEvents.isEmpty else { return }

        stop(resetStatus: false)
        isPlaying = true
        isPaused = false
        statusMessage = "Aguardando \(Int(startDelaySeconds))s para voce focar o Roblox..."

        let events = parsedEvents
        playbackTask = Task { [weak self] in
            await self?.runPlayback(events)
        }
    }

    func pause() {
        guard isPlaying else { return }
        isPaused = true
        statusMessage = "Pausado"
    }

    func stop(resetStatus: Bool = true) {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        isPaused = false
        currentEventIndex = 0
        if resetStatus {
            statusMessage = "Parado"
        }
    }

    private func runPlayback(_ events: [PianoSheetEvent]) async {
        do {
            try await Task.sleep(nanoseconds: UInt64(max(0, startDelaySeconds) * 1_000_000_000))

            let stepDuration = max(0.02, tempoMilliseconds / 1000)
            let holdDuration = max(0.01, stepDuration * min(max(holdPercentage, 5), 95) / 100)

            for (index, event) in events.enumerated() {
                try Task.checkCancellation()

                while isPaused {
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 100_000_000)
                }

                currentEventIndex = index + 1

                switch event.kind {
                case .chord(let keys):
                    statusMessage = "Tocando \(event.displayName)"
                    try await KeyboardSimulator.shared.pressChord(keys, holdDuration: holdDuration)
                    let remaining = max(0, stepDuration - holdDuration)
                    try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))

                case .rest(let units):
                    statusMessage = "Pausa"
                    let restDuration = stepDuration * Double(max(1, units))
                    try await Task.sleep(nanoseconds: UInt64(restDuration * 1_000_000_000))
                }
            }

            isPlaying = false
            isPaused = false
            statusMessage = "Concluido"
        } catch is CancellationError {
            statusMessage = "Parado"
        } catch {
            isPlaying = false
            isPaused = false
            statusMessage = error.localizedDescription
        }
    }
}
