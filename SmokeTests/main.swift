import Foundation
import GoodnessRobloxClientCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Falhou: \(message)\n", stderr)
        exit(1)
    }
}

let compact = PianoSheetParser.parse("[6psu]O[6p]a", options: PianoSheetParserOptions(whitespaceCreatesRests: false))
expect(compact.count == 4, "quantidade de eventos compactos")
expect(compact[0].kind == .chord(["6", "p", "s", "u"]), "acorde inicial")
expect(compact[1].kind == .chord(["O"]), "nota maiuscula")
expect(compact[2].kind == .chord(["6", "p"]), "segundo acorde")
expect(compact[3].kind == .chord(["a"]), "nota final")

let spaced = PianoSheetParser.parse("[6]  [7]\n8", options: PianoSheetParserOptions(whitespaceCreatesRests: true, newlineRestUnits: 3))
expect(spaced.count == 5, "quantidade com pausas")
expect(spaced[0].kind == .chord(["6"]), "primeira nota")
expect(spaced[1].kind == .rest(2), "pausa por espacos")
expect(spaced[2].kind == .chord(["7"]), "segunda nota")
expect(spaced[3].kind == .rest(3), "pausa por quebra de linha")
expect(spaced[4].kind == .chord(["8"]), "terceira nota")

let separatorsOnly = PianoSheetParser.parse("[6]  [7]\n8", options: PianoSheetParserOptions(whitespaceCreatesRests: false))
expect(separatorsOnly.map(\.displayName) == ["6", "7", "8"], "espacos como separadores")

print("ParserSmokeTest OK")


// Detector de notas: quadros sintéticos independentes do Roblox.
expect(RhythmInstrument.drums.defaultLanes.map(\.key) == ["x", "c", "n", "m"], "teclas da bateria")
expect(RhythmInstrument.guitar.defaultLanes.map(\.key) == ["f", "j"], "teclas da guitarra")

let frameWidth = 400
let frameHeight = 320
let visionLanes = [
    RhythmLane(key: "x", x: 0.25, y: 0.80),
    RhythmLane(key: "c", x: 0.75, y: 0.80)
]
let visionSettings = RhythmVisionSettings()

func makeFrame(noteY: Int) -> [UInt8] {
    var pixels = [UInt8](repeating: 8, count: frameWidth * frameHeight * 4)
    for centerX in [100, 300] {
        for y in max(0, noteY - 19)...min(frameHeight - 1, noteY + 19) {
            for x in max(0, centerX - 19)...min(frameWidth - 1, centerX + 19) {
                let dx = x - centerX
                let dy = y - noteY
                if dx * dx + dy * dy <= 19 * 19 {
                    let offset = (y * frameWidth + x) * 4
                    pixels[offset] = 210   // B
                    pixels[offset + 1] = 54 // G
                    pixels[offset + 2] = 244 // R: magenta
                    pixels[offset + 3] = 255
                }
            }
        }
    }
    return pixels
}

func analyzeTestFrame(_ detector: RhythmVisionDetector, y: Int, at time: TimeInterval) -> RhythmFrameResult {
    let pixels = makeFrame(noteY: y)
    return pixels.withUnsafeBufferPointer { buffer in
        detector.analyze(
            bgra: buffer.baseAddress!,
            width: frameWidth,
            height: frameHeight,
            bytesPerRow: frameWidth * 4,
            time: time,
            lanes: visionLanes,
            settings: visionSettings
        )
    }
}

let staticDetector = RhythmVisionDetector()
var staticHits = 0
for index in 0..<12 {
    staticHits += analyzeTestFrame(staticDetector, y: 250, at: Double(index) * 0.04).triggeredKeys.count
}
expect(staticHits == 0, "imagem estatica nao deve acionar teclas")

let movingDetector = RhythmVisionDetector()
var movingHits: [Character] = []
for (index, y) in [190, 207, 224, 240, 253, 265, 279].enumerated() {
    movingHits.append(contentsOf: analyzeTestFrame(
        movingDetector,
        y: y,
        at: Double(index) * 0.04
    ).triggeredKeys)
}
expect(movingHits.sorted() == ["c", "x"], "notas moveis devem acionar ambas as faixas uma unica vez")

print("RhythmVisionSmokeTest OK")


// O mesmo HUD com 4 receptores coloridos do screenshot do Roblox.
// Background laranja e interior escuro impedem que uma tela qualquer passe como receptor.
let hudWidth = 679
let hudHeight = 426
let receiverPositions: [(x: Int, y: Int, rgb: (UInt8, UInt8, UInt8))] = [
    (151, 241, (230, 114, 185)), // X rosa
    (246, 241, (244, 201, 135)), // C amarelo
    (341, 241, (84, 141, 94)),   // N verde
    (436, 241, (91, 135, 184))   // M azul
]

func makeReceiverHUD() -> [UInt8] {
    var buffer = [UInt8](repeating: 0, count: hudWidth * hudHeight * 4)
    for y in 0..<hudHeight {
        for x in 0..<hudWidth {
            let offset = (y * hudWidth + x) * 4
            buffer[offset] = 38
            buffer[offset + 1] = 81
            buffer[offset + 2] = 167
            buffer[offset + 3] = 255
        }
    }

    for receiver in receiverPositions {
        for y in (receiver.y - 44)...(receiver.y + 44) {
            for x in (receiver.x - 44)...(receiver.x + 44) {
                let dx = x - receiver.x
                let dy = y - receiver.y
                let distanceSquared = dx * dx + dy * dy
                let offset = (y * hudWidth + x) * 4
                if distanceSquared <= 41 * 41 {
                    buffer[offset] = 21
                    buffer[offset + 1] = 21
                    buffer[offset + 2] = 21
                }
                if distanceSquared >= 34 * 34 && distanceSquared <= 37 * 37 {
                    buffer[offset] = receiver.rgb.2
                    buffer[offset + 1] = receiver.rgb.1
                    buffer[offset + 2] = receiver.rgb.0
                }
            }
        }
    }
    return buffer
}

let receiverHUD = makeReceiverHUD()
let located = receiverHUD.withUnsafeBufferPointer { pixels in
    RhythmReceptorLocator.locate(
        bgra: pixels.baseAddress!,
        width: hudWidth,
        height: hudHeight,
        bytesPerRow: hudWidth * 4,
        keys: ["x", "c", "n", "m"]
    )
}
expect(located?.count == 4, "localizacao automatica dos quatro receptores")
if let located {
    for (actual, expected) in zip(located, receiverPositions) {
        expect(abs(actual.x - Double(expected.x) / Double(hudWidth)) < 0.040, "eixo X do receptor")
        expect(abs(actual.y - Double(expected.y) / Double(hudHeight)) < 0.045, "eixo Y do receptor")
    }
}

let guitarLocated = receiverHUD.withUnsafeBufferPointer { pixels in
    RhythmReceptorLocator.locate(
        bgra: pixels.baseAddress!,
        width: hudWidth,
        height: hudHeight,
        bytesPerRow: hudWidth * 4,
        keys: ["f", "j"]
    )
}
expect(guitarLocated?.count == 2, "localizacao dos dois receptores da guitarra")

let noReceivers = [UInt8](repeating: 0, count: hudWidth * hudHeight * 4)
let noneLocated = noReceivers.withUnsafeBufferPointer { pixels in
    RhythmReceptorLocator.locate(
        bgra: pixels.baseAddress!,
        width: hudWidth,
        height: hudHeight,
        bytesPerRow: hudWidth * 4,
        keys: ["x", "c", "n", "m"]
    )
}
expect(noneLocated == nil, "imagem vazia nao possui receptores")

func makeBlueNoteFrame(_ noteY: Int) -> [UInt8] {
    var pixels = makeFrame(noteY: noteY)
    for i in stride(from: 0, to: pixels.count, by: 4) {
        if pixels[i] == 210 && pixels[i + 1] == 54 && pixels[i + 2] == 244 {
            pixels[i] = 244
            pixels[i + 1] = 162
            pixels[i + 2] = 30
        }
    }
    return pixels
}

func analyzeBlue(_ detector: RhythmVisionDetector, y: Int, time: TimeInterval, mode: RhythmNoteDetectionMode) -> RhythmFrameResult {
    let pixels = makeBlueNoteFrame(y)
    return pixels.withUnsafeBufferPointer { buffer in
        detector.analyze(
            bgra: buffer.baseAddress!,
            width: frameWidth,
            height: frameHeight,
            bytesPerRow: frameWidth * 4,
            time: time,
            lanes: visionLanes,
            settings: RhythmVisionSettings(detectionMode: mode)
        )
    }
}

let motionDetector = RhythmVisionDetector()
var motionHits: [Character] = []
for (index, y) in [190, 207, 224, 240, 253, 265, 279].enumerated() {
    motionHits.append(contentsOf: analyzeBlue(
        motionDetector,
        y: y,
        time: Double(index) * 0.04,
        mode: .movement
    ).triggeredKeys)
}
expect(motionHits.sorted() == ["c", "x"], "detectar notas em movimento independente da cor")

print("RhythmReceptorAndMotionSmokeTest OK")
