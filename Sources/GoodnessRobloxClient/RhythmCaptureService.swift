import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import GoodnessRobloxClientCore
import ScreenCaptureKit

struct RhythmCaptureOption: Identifiable, Hashable {
    let id: String
    let title: String
}

enum RhythmCaptureError: LocalizedError {
    case sourceMissing

    var errorDescription: String? {
        switch self {
        case .sourceMissing:
            return "Fonte de vídeo indisponível. Atualize a lista de janelas."
        }
    }
}

/// A captura é independente do player de Piano Sheets.
@MainActor
final class RhythmCaptureService {
    private enum Source {
        case window(SCWindow)
        case display(SCDisplay)
    }

    private var sources: [String: Source] = [:]
    private var stream: SCStream?
    private let processor = RhythmFrameProcessor()

    func discoverSources() async throws -> [RhythmCaptureOption] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        var options: [RhythmCaptureOption] = []
        var available: [String: Source] = [:]

        for window in content.windows {
            let appName = window.owningApplication?.applicationName ?? ""
            let title = window.title ?? ""
            let isRoblox = appName.localizedCaseInsensitiveContains("Roblox")
                || title.localizedCaseInsensitiveContains("Roblox")
            guard isRoblox, window.frame.width >= 250, window.frame.height >= 180 else {
                continue
            }
            let id = "window:\(window.windowID)"
            available[id] = .window(window)
            options.append(RhythmCaptureOption(
                id: id,
                title: "Roblox • \(title.isEmpty ? appName : title)"
            ))
        }

        for (index, display) in content.displays.enumerated() {
            let id = "display:\(display.displayID)"
            available[id] = .display(display)
            options.append(RhythmCaptureOption(
                id: id,
                title: "Tela \(index + 1) • captura completa"
            ))
        }

        sources = available
        return options
    }

    func start(
        sourceID: String,
        lanes: [RhythmLane],
        settings: RhythmVisionSettings,
        onPreview: @escaping (CGImage) -> Void,
        onKeys: @escaping ([Character]) -> Void,
        onNoteCount: @escaping (Int) -> Void
    ) async throws {
        guard let source = sources[sourceID] else {
            throw RhythmCaptureError.sourceMissing
        }
        await stop()

        let filter: SCContentFilter
        let sourceWidth: Int
        let sourceHeight: Int

        switch source {
        case .window(let window):
            filter = SCContentFilter(desktopIndependentWindow: window)
            sourceWidth = max(1, Int(window.frame.width))
            sourceHeight = max(1, Int(window.frame.height))

        case .display(let display):
            filter = SCContentFilter(display: display, excludingWindows: [])
            sourceWidth = max(1, display.width)
            sourceHeight = max(1, display.height)
        }

        // Captura limitada para não consumir toda a GPU com vídeo 4K/5K.
        let scale = min(1, 1600.0 / Double(sourceWidth))
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(Double(sourceWidth) * scale))
        configuration.height = max(1, Int(Double(sourceHeight) * scale))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.queueDepth = 3
        configuration.capturesAudio = false

        processor.activate(
            lanes: lanes,
            settings: settings,
            onPreview: onPreview,
            onKeys: onKeys,
            onNoteCount: onNoteCount
        )

        let newStream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: nil
        )
        try newStream.addStreamOutput(
            processor,
            type: .screen,
            sampleHandlerQueue: processor.queue
        )
        stream = newStream
        do {
            try await newStream.startCapture()
        } catch {
            processor.deactivate()
            stream = nil
            throw error
        }
    }

    func update(lanes: [RhythmLane], settings: RhythmVisionSettings) {
        processor.update(lanes: lanes, settings: settings)
    }

    /// Solicita um único reconhecimento no próximo frame, sem bloquear a UI.
    func locateReceivers(
        keys: [Character],
        onResult: @escaping ([RhythmLane]?) -> Void
    ) {
        processor.requestReceptorLocation(keys: keys, onResult: onResult)
    }

    func stop() async {
        let current = stream
        stream = nil
        processor.deactivate()
        if let current {
            try? await current.stopCapture()
        }
    }
}

/// Apenas esta fila lê e modifica o rastreador, evitando corrida de dados.
private final class RhythmFrameProcessor: NSObject, SCStreamOutput {
    let queue = DispatchQueue(label: "goodness.rhythm.capture", qos: .userInteractive)

    private let detector = RhythmVisionDetector()
    private let imageContext = CIContext(options: [.useSoftwareRenderer: false])
    private var active = false
    private var lanes: [RhythmLane] = []
    private var settings = RhythmVisionSettings()
    private var onPreview: ((CGImage) -> Void)?
    private var onKeys: (([Character]) -> Void)?
    private var onNoteCount: ((Int) -> Void)?
    private var lastPreviewTime: TimeInterval = 0
    private var lastMetricsTime: TimeInterval = 0
    private var pendingReceptorKeys: [Character]?
    private var onReceptorLocation: (([RhythmLane]?) -> Void)?

    func activate(
        lanes: [RhythmLane],
        settings: RhythmVisionSettings,
        onPreview: @escaping (CGImage) -> Void,
        onKeys: @escaping ([Character]) -> Void,
        onNoteCount: @escaping (Int) -> Void
    ) {
        queue.async {
            self.detector.reset()
            self.lanes = lanes
            self.settings = settings
            self.onPreview = onPreview
            self.onKeys = onKeys
            self.onNoteCount = onNoteCount
            self.lastPreviewTime = 0
            self.lastMetricsTime = 0
            self.pendingReceptorKeys = nil
            self.onReceptorLocation = nil
            self.active = true
        }
    }

    func update(lanes: [RhythmLane], settings: RhythmVisionSettings) {
        queue.async {
            if self.lanes != lanes {
                self.detector.reset()
            }
            self.lanes = lanes
            self.settings = settings
        }
    }

    func requestReceptorLocation(
        keys: [Character],
        onResult: @escaping ([RhythmLane]?) -> Void
    ) {
        queue.async {
            self.pendingReceptorKeys = keys
            self.onReceptorLocation = onResult
        }
    }

    func deactivate() {
        queue.async {
            self.active = false
            self.detector.reset()
            self.onPreview = nil
            self.onKeys = nil
            self.onNoteCount = nil
            self.pendingReceptorKeys = nil
            self.onReceptorLocation = nil
        }
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard active, type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              CVPixelBufferGetPixelFormatType(imageBuffer) == kCVPixelFormatType_32BGRA else {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        if let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) {
            let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
            if let requestedKeys = pendingReceptorKeys {
                pendingReceptorKeys = nil
                let result = RhythmReceptorLocator.locate(
                    bgra: pixels,
                    width: CVPixelBufferGetWidth(imageBuffer),
                    height: CVPixelBufferGetHeight(imageBuffer),
                    bytesPerRow: CVPixelBufferGetBytesPerRow(imageBuffer),
                    keys: requestedKeys
                )
                onReceptorLocation?(result)
                onReceptorLocation = nil
            }

            let result = detector.analyze(
                bgra: pixels,
                width: CVPixelBufferGetWidth(imageBuffer),
                height: CVPixelBufferGetHeight(imageBuffer),
                bytesPerRow: CVPixelBufferGetBytesPerRow(imageBuffer),
                time: now,
                lanes: lanes,
                settings: settings
            )
            if !result.triggeredKeys.isEmpty {
                onKeys?(result.triggeredKeys)
            }
            if now - lastMetricsTime >= 0.25 {
                lastMetricsTime = now
                onNoteCount?(result.visibleNotes)
            }
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

        if now - lastPreviewTime >= 0.35 {
            lastPreviewTime = now
            let image = CIImage(cvPixelBuffer: imageBuffer)
            if let preview = imageContext.createCGImage(image, from: image.extent) {
                onPreview?(preview)
            }
        }
    }
}
