import Foundation

public struct PianoSheetParserOptions: Equatable {
    public var whitespaceCreatesRests = true
    public var newlineRestUnits = 2
    public var tabRestUnits = 2

    public init(whitespaceCreatesRests: Bool = true, newlineRestUnits: Int = 2, tabRestUnits: Int = 2) {
        self.whitespaceCreatesRests = whitespaceCreatesRests
        self.newlineRestUnits = newlineRestUnits
        self.tabRestUnits = tabRestUnits
    }
}

public enum PianoSheetParser {
    public static func parse(_ input: String, options: PianoSheetParserOptions) -> [PianoSheetEvent] {
        var events: [PianoSheetEvent] = []
        var index = input.startIndex
        var pendingRestUnits = 0

        func flushRest() {
            guard options.whitespaceCreatesRests, pendingRestUnits > 0 else {
                pendingRestUnits = 0
                return
            }

            events.append(PianoSheetEvent(kind: .rest(pendingRestUnits), source: String(repeating: " ", count: pendingRestUnits)))
            pendingRestUnits = 0
        }

        while index < input.endIndex {
            let character = input[index]

            if character == "[" {
                flushRest()

                let chordStart = index
                index = input.index(after: index)
                var chord: [Character] = []
                var didCloseChord = false

                while index < input.endIndex {
                    let chordCharacter = input[index]
                    if chordCharacter == "]" {
                        didCloseChord = true
                        index = input.index(after: index)
                        break
                    }

                    if !chordCharacter.isSheetWhitespace {
                        chord.append(chordCharacter)
                    }
                    index = input.index(after: index)
                }

                if !chord.isEmpty {
                    let end = didCloseChord ? index : input.endIndex
                    events.append(PianoSheetEvent(kind: .chord(chord), source: String(input[chordStart..<end])))
                }
                continue
            }

            if character.isSheetWhitespace {
                if character == "\n" || character == "\r" {
                    pendingRestUnits += options.newlineRestUnits
                } else if character == "\t" {
                    pendingRestUnits += options.tabRestUnits
                } else {
                    pendingRestUnits += 1
                }
                index = input.index(after: index)
                continue
            }

            flushRest()
            events.append(PianoSheetEvent(kind: .chord([character]), source: String(character)))
            index = input.index(after: index)
        }

        return events
    }
}

private extension Character {
    var isSheetWhitespace: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}
