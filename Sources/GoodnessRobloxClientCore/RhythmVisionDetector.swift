import Foundation

/// Posição normalizada (0...1) da área de acerto de uma tecla na imagem capturada.
public struct RhythmLane: Codable, Equatable {
    public var key: Character
    public var x: Double
    public var y: Double

    public init(key: Character, x: Double, y: Double) {
        self.key = key
        self.x = x
        self.y = y
    }
}

public enum RhythmInstrument: String, CaseIterable, Identifiable {
    case drums
    case bass
    case guitar
    case keyboard

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .drums: return "Bateria"
        case .bass: return "Baixo"
        case .guitar: return "Guitarra"
        case .keyboard: return "Teclado"
        }
    }

    public var defaultLanes: [RhythmLane] {
        let xs: [Double]
        let y: Double
        let keys: [Character]

        switch self {
        case .drums:
            xs = [0.29, 0.45, 0.61, 0.77]
            y = 0.87
            keys = ["x", "c", "n", "m"]
        case .bass:
            xs = [0.26, 0.415, 0.57, 0.725]
            y = 0.86
            keys = ["x", "c", "n", "m"]
        case .guitar:
            xs = [0.23, 0.54]
            y = 0.90
            keys = ["f", "j"]
        case .keyboard:
            xs = [0.26, 0.415, 0.57, 0.73]
            y = 0.89
            keys = ["x", "c", "n", "m"]
        }
        return zip(keys, xs).map { RhythmLane(key: $0.0, x: $0.1, y: y) }
    }
}

public struct RhythmVisionSettings: Equatable {
    public var hueDegrees: Double
    public var toleranceDegrees: Double
    public var minimumSaturation: Double
    public var scanDepth: Double
    public var leadPixels: Double

    public init(
        hueDegrees: Double = 307,
        toleranceDegrees: Double = 34,
        minimumSaturation: Double = 0.44,
        scanDepth: Double = 0.30,
        leadPixels: Double = 12
    ) {
        self.hueDegrees = hueDegrees
        self.toleranceDegrees = toleranceDegrees
        self.minimumSaturation = minimumSaturation
        self.scanDepth = scanDepth
        self.leadPixels = leadPixels
    }
}

public struct RhythmFrameResult {
    public let triggeredKeys: [Character]
    public let visibleNotes: Int
}

/// Detecta círculos coloridos em cada faixa e só dispara quando uma forma se move
/// em direção à linha de acerto. Não acessa memória nem arquivos do jogo.
/// Deve ser utilizado por uma única fila serial de captura de tela.
public final class RhythmVisionDetector {
    private struct NoteTrack {
        var position: Double
        var velocity: Double
        var lastSeen: TimeInterval
        var fired: Bool
    }

    private var tracks: [[NoteTrack]] = []
    private var lastHitTimes: [TimeInterval] = []

    public init() { }

    public func reset() {
        tracks.removeAll()
        lastHitTimes.removeAll()
    }

    public func analyze(
        bgra: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        time: TimeInterval,
        lanes: [RhythmLane],
        settings: RhythmVisionSettings
    ) -> RhythmFrameResult {
        guard width > 64, height > 64, bytesPerRow >= width * 4, !lanes.isEmpty else {
            return RhythmFrameResult(triggeredKeys: [], visibleNotes: 0)
        }

        if tracks.count != lanes.count {
            tracks = Array(repeating: [], count: lanes.count)
            lastHitTimes = Array(repeating: -1000, count: lanes.count)
        }

        let laneDistance: Double
        if lanes.count > 1 {
            laneDistance = zip(lanes, lanes.dropFirst())
                .map { abs($0.0.x - $0.1.x) }
                .min() ?? 0.15
        } else {
            laneDistance = 0.15
        }
        let halfWidth = max(8, min(28, Int(laneDistance * Double(width) * 0.20)))
        var firedKeys: [Character] = []
        var visibleNotes = 0

        for (laneIndex, lane) in lanes.enumerated() {
            let candidates = findNotes(
                bgra: bgra,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                lane: lane,
                halfWidth: halfWidth,
                settings: settings
            )
            visibleNotes += candidates.count
            var existing = tracks[laneIndex].filter { time - $0.lastSeen < 0.32 }
            var used = Set<Int>()

            // Próximas notas podem coexistir na mesma faixa; cada mancha
            // colorida mantém seu próprio histórico e estado de disparo.
            for centerY in candidates.sorted(by: >) {
                var bestIndex: Int?
                var bestDistance = Double.infinity
                for index in existing.indices where !used.contains(index) {
                    let old = existing[index]
                    let dt = max(0, time - old.lastSeen)
                    let distance = abs(centerY - old.position)
                    if distance < max(0.055, min(0.16, dt * 1.8)), distance < bestDistance {
                        bestIndex = index
                        bestDistance = distance
                    }
                }

                if let index = bestIndex {
                    used.insert(index)
                    let old = existing[index]
                    let dt = max(0.001, time - old.lastSeen)
                    let observedVelocity = (centerY - old.position) / dt
                    // Movimento descendente: direção do receptor das notas.
                    let velocity = 0.35 * old.velocity + 0.65 * observedVelocity
                    existing[index].position = centerY
                    existing[index].velocity = velocity
                    existing[index].lastSeen = time

                    let target = lane.y - settings.leadPixels / Double(height)
                    if !old.fired,
                       velocity > 0.075,
                       centerY >= target,
                       centerY <= lane.y + 0.035,
                       time - lastHitTimes[laneIndex] > 0.075 {
                        firedKeys.append(lane.key)
                        existing[index].fired = true
                        lastHitTimes[laneIndex] = time
                    }
                } else {
                    existing.append(NoteTrack(
                        position: centerY,
                        velocity: 0,
                        lastSeen: time,
                        fired: false
                    ))
                    used.insert(existing.count - 1)
                }
            }
            // Mantém por pouco tempo os rastros não encontrados nesta imagem.
            tracks[laneIndex] = existing
        }

        return RhythmFrameResult(triggeredKeys: firedKeys, visibleNotes: visibleNotes)
    }

    private func findNotes(
        bgra: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        lane: RhythmLane,
        halfWidth: Int,
        settings: RhythmVisionSettings
    ) -> [Double] {
        let centerX = Int(lane.x * Double(width))
        guard centerX >= halfWidth, centerX < width - halfWidth else { return [] }
        let startY = max(0, Int((lane.y - settings.scanDepth) * Double(height)))
        let endY = min(height - 1, Int((lane.y + 0.030) * Double(height)))
        guard endY > startY else { return [] }

        let sampleStep = 3
        let samples = stride(from: centerX - halfWidth, through: centerX + halfWidth, by: sampleStep)
        let sampleCount = (2 * halfWidth) / sampleStep + 1
        let requiredHits = max(3, Int(Double(sampleCount) * 0.39))

        var bands: [(Int, Int)] = []
        var firstMatchingY: Int?
        var lastMatchingY: Int = 0
        var consecutiveMisses = 0

        for y in stride(from: startY, through: endY, by: 2) {
            var hits = 0
            let rowOffset = y * bytesPerRow
            for x in samples {
                let offset = rowOffset + x * 4
                if matchesHue(
                    blue: bgra[offset],
                    green: bgra[offset + 1],
                    red: bgra[offset + 2],
                    settings: settings
                ) {
                    hits += 1
                }
            }

            if hits >= requiredHits {
                if firstMatchingY == nil { firstMatchingY = y }
                lastMatchingY = y
                consecutiveMisses = 0
            } else if firstMatchingY != nil {
                consecutiveMisses += 1
                if consecutiveMisses >= 2 {
                    bands.append((firstMatchingY!, lastMatchingY))
                    firstMatchingY = nil
                    consecutiveMisses = 0
                }
            }
        }
        if let firstMatchingY {
            bands.append((firstMatchingY, lastMatchingY))
        }

        let minimumHeight = max(6, Int(Double(height) * 0.006))
        let maximumHeight = max(28, Int(Double(height) * 0.15))
        return bands.compactMap { start, end in
            let bandHeight = end - start + 2
            guard bandHeight >= minimumHeight, bandHeight <= maximumHeight else {
                return nil
            }
            return Double(start + end) / (2 * Double(height))
        }
    }

    private func matchesHue(
        blue: UInt8,
        green: UInt8,
        red: UInt8,
        settings: RhythmVisionSettings
    ) -> Bool {
        let r = Double(red) / 255
        let g = Double(green) / 255
        let b = Double(blue) / 255
        let high = max(r, max(g, b))
        let low = min(r, min(g, b))
        let delta = high - low
        guard high >= 0.35,
              delta > 0.001,
              delta / high >= settings.minimumSaturation else { return false }

        let hue: Double
        if high == r {
            hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if high == g {
            hue = 60 * ((b - r) / delta + 2)
        } else {
            hue = 60 * ((r - g) / delta + 4)
        }
        let normalized = hue < 0 ? hue + 360 : hue
        let diff = abs(normalized - settings.hueDegrees)
        return min(diff, 360 - diff) <= settings.toleranceDegrees
    }
}
