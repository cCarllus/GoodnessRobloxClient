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
