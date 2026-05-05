import Foundation

public enum PianoSheetEventKind: Equatable {
    case chord([Character])
    case rest(Int)
}

public struct PianoSheetEvent: Identifiable, Equatable {
    public let id = UUID()
    public let kind: PianoSheetEventKind
    public let source: String

    public init(kind: PianoSheetEventKind, source: String) {
        self.kind = kind
        self.source = source
    }

    public var displayName: String {
        switch kind {
        case .chord(let keys):
            return keys.count > 1 ? "[\(String(keys))]" : String(keys)
        case .rest(let units):
            return units > 1 ? "pausa x\(units)" : "pausa"
        }
    }
}
