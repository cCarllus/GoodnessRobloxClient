import Foundation

/// Localiza os receptores coloridos de HUD sem ler memória do jogo.
/// Reconhecimento por votos de anel circular e alinhamento horizontal.
public enum RhythmReceptorLocator {
    private struct ColorSpec {
        var key: Character
        var hue: Double
        var tolerance: Double
        var minimumSaturation: Double
        var minimumBrightness: Double
    }

    private struct Candidate {
        var x: Double
        var y: Double
        var score: Int
        var colorMaximum: Int

        var normalizedScore: Double {
            Double(score) / Double(max(1, colorMaximum))
        }
    }

    private static let ringDirections: [(Double, Double)] = (0..<12).map { index in
        let angle = Double(index) * .pi / 6
        return (cos(angle), sin(angle))
    }

    /// Retorna nil se nenhum grupo confiável de receptores for encontrado.
    /// A imagem é BGRA com origem no canto superior esquerdo.
    public static func locate(
        bgra: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        keys: [Character]
    ) -> [RhythmLane]? {
        guard width >= 240, height >= 200,
              bytesPerRow >= width * 4,
              (keys.count == 2 || keys.count == 4) else { return nil }
        guard let specs = specifications(for: keys) else { return nil }

        let gridStep = max(4, width / 450)
        let gridWidth = (width + gridStep - 1) / gridStep
        let gridHeight = (height + gridStep - 1) / gridStep
        let sampleStep = max(2, width / 750)
        let maxRadius = min(72, max(28, min(width, height) / 6))
        let radii = Array(stride(from: 20, through: maxRadius, by: 6))
        guard !radii.isEmpty else { return nil }

        var candidateGroups: [[Candidate]] = []
        for spec in specs {
            var votes = [UInt16](repeating: 0, count: gridWidth * gridHeight)
            let startY = max(0, Int(Double(height) * 0.15))

            for y in stride(from: startY, to: height, by: sampleStep) {
                let row = y * bytesPerRow
                for x in stride(from: 0, to: width, by: sampleStep) {
                    let offset = row + x * 4
                    guard matchesColor(
                        blue: bgra[offset],
                        green: bgra[offset + 1],
                        red: bgra[offset + 2],
                        spec: spec
                    ) else { continue }

                    for radius in radii {
                        for (dx, dy) in ringDirections {
                            let centerX = x - Int((dx * Double(radius)).rounded())
                            let centerY = y - Int((dy * Double(radius)).rounded())
                            guard centerX >= 0, centerX < width,
                                  centerY >= startY, centerY < height else { continue }
                            let index = (centerY / gridStep) * gridWidth + centerX / gridStep
                            if votes[index] < UInt16.max { votes[index] += 1 }
                        }
                    }
                }
            }

            let maximum = Int(votes.max() ?? 0)
            guard maximum >= 13 else { return nil }
            let minimumScore = max(12, Int(Double(maximum) * 0.42))

            let ranked = votes.indices
                .filter { Int(votes[$0]) >= minimumScore }
                .sorted { votes[$0] > votes[$1] }

            var chosen: [Candidate] = []
            for index in ranked {
                let centerX = (index % gridWidth) * gridStep
                let centerY = (index / gridWidth) * gridStep
                guard centerX > width / 18, centerX < width * 17 / 18,
                      centerY > startY, centerY < height * 96 / 100,
                      isDarkCenter(
                        bgra: bgra,
                        x: centerX,
                        y: centerY,
                        bytesPerRow: bytesPerRow
                      ) else { continue }

                let refined = refinedCenter(
                    votes: votes,
                    gridWidth: gridWidth,
                    gridHeight: gridHeight,
                    gridStep: gridStep,
                    index: index
                )
                guard !chosen.contains(where: {
                    hypot($0.x - refined.x, $0.y - refined.y) < 28
                }) else { continue }

                chosen.append(Candidate(
                    x: refined.x,
                    y: refined.y,
                    score: Int(votes[index]),
                    colorMaximum: maximum
                ))
                if chosen.count == 9 { break }
            }
            guard !chosen.isEmpty else { return nil }
            candidateGroups.append(chosen)
        }

        var bestSelection: [Candidate]?
        var bestScore = -Double.infinity
        var selection: [Candidate] = []

        func choose(_ index: Int) {
            if index == candidateGroups.count {
                let ys = selection.map(\.y)
                let spread = (ys.max() ?? 0) - (ys.min() ?? 0)
                let maxSpread = max(19, Double(height) * 0.07)
                guard spread <= maxSpread else { return }

                let gaps = zip(selection, selection.dropFirst()).map { $0.1.x - $0.0.x }
                guard gaps.allSatisfy({ $0 >= Double(width) * 0.035 && $0 <= Double(width) * 0.37 }),
                      let smallest = gaps.min(),
                      let largest = gaps.max(),
                      smallest >= largest * 0.48 else { return }

                let average = gaps.reduce(0, +) / Double(gaps.count)
                let irregularity = gaps.reduce(0) { $0 + abs($1 - average) } / Double(gaps.count)
                let score = selection.reduce(0) { $0 + $1.normalizedScore }
                    - spread / maxSpread * 0.38
                    - irregularity / max(1, average) * 0.34

                if score > bestScore {
                    bestScore = score
                    bestSelection = selection
                }
                return
            }

            for candidate in candidateGroups[index] {
                if let last = selection.last, candidate.x <= last.x { continue }
                selection.append(candidate)
                choose(index + 1)
                selection.removeLast()
            }
        }
        choose(0)

        guard let found = bestSelection else { return nil }
        return zip(keys, found).map { key, candidate in
            RhythmLane(
                key: key,
                x: min(1, max(0, candidate.x / Double(width))),
                y: min(1, max(0, candidate.y / Double(height)))
            )
        }
    }

    private static func specifications(for keys: [Character]) -> [ColorSpec]? {
        let palette: [Character: ColorSpec] = [
            "x": ColorSpec(key: "x", hue: 317, tolerance: 27, minimumSaturation: 0.19, minimumBrightness: 0.25),
            "c": ColorSpec(key: "c", hue: 43, tolerance: 19, minimumSaturation: 0.19, minimumBrightness: 0.31),
            "n": ColorSpec(key: "n", hue: 137, tolerance: 30, minimumSaturation: 0.14, minimumBrightness: 0.21),
            "m": ColorSpec(key: "m", hue: 210, tolerance: 29, minimumSaturation: 0.14, minimumBrightness: 0.22),
            "f": ColorSpec(key: "f", hue: 137, tolerance: 30, minimumSaturation: 0.14, minimumBrightness: 0.21),
            "j": ColorSpec(key: "j", hue: 210, tolerance: 29, minimumSaturation: 0.14, minimumBrightness: 0.22)
        ]
        var result: [ColorSpec] = []
        for key in keys {
            guard let spec = palette[key] else { return nil }
            result.append(spec)
        }
        return result
    }

    private static func matchesColor(
        blue: UInt8,
        green: UInt8,
        red: UInt8,
        spec: ColorSpec
    ) -> Bool {
        let r = Double(red) / 255
        let g = Double(green) / 255
        let b = Double(blue) / 255
        let high = max(r, max(g, b))
        let low = min(r, min(g, b))
        let delta = high - low
        guard high >= spec.minimumBrightness,
              delta > 0.001,
              delta / high >= spec.minimumSaturation else { return false }

        let hue: Double
        if high == r {
            hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if high == g {
            hue = 60 * ((b - r) / delta + 2)
        } else {
            hue = 60 * ((r - g) / delta + 4)
        }
        let normalized = hue < 0 ? hue + 360 : hue
        let difference = abs(normalized - spec.hue)
        return min(difference, 360 - difference) <= spec.tolerance
    }

    private static func isDarkCenter(
        bgra: UnsafePointer<UInt8>,
        x: Int,
        y: Int,
        bytesPerRow: Int
    ) -> Bool {
        // Receptores do HUD: fundo preto/cinza escuro e aro colorido.
        let offset = y * bytesPerRow + x * 4
        let brightness = max(bgra[offset], max(bgra[offset + 1], bgra[offset + 2]))
        return brightness < 150
    }

    private static func refinedCenter(
        votes: [UInt16],
        gridWidth: Int,
        gridHeight: Int,
        gridStep: Int,
        index: Int
    ) -> (x: Double, y: Double) {
        let centerX = index % gridWidth
        let centerY = index / gridWidth
        let minimum = max(1, Int(votes[index]) / 4)
        var sumX = 0.0
        var sumY = 0.0
        var weightSum = 0.0

        for y in max(0, centerY - 4)...min(gridHeight - 1, centerY + 4) {
            for x in max(0, centerX - 4)...min(gridWidth - 1, centerX + 4) {
                let count = max(0, Int(votes[y * gridWidth + x]) - minimum)
                let weight = Double(count * count * count)
                sumX += Double(x * gridStep) * weight
                sumY += Double(y * gridStep) * weight
                weightSum += weight
            }
        }
        guard weightSum > 0 else {
            return (x: Double(centerX * gridStep), y: Double(centerY * gridStep))
        }
        return (x: sumX / weightSum, y: sumY / weightSum)
    }
}
