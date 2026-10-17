# Architecture

Goodness Roblox Client is organized as a Swift Package with one app target, one core target, and one smoke-test executable.

## Targets

| Target | Path | Responsibility |
| --- | --- | --- |
| `GoodnessRobloxClient` | `Sources/GoodnessRobloxClient` | SwiftUI app, screens, controls, and view models |
| `GoodnessRobloxClientCore` | `Sources/GoodnessRobloxClientCore` | Piano sheet parsing, event models, and keyboard simulation |
| `ParserSmokeTest` | `SmokeTests` | Lightweight parser validation without XCTest dependency |

## Feature Boundaries

`Piano Sheets` is a feature inside Goodness Roblox Client. Keep feature code named around piano sheets only when it describes the feature, not the whole product.

The expected flow is:

1. `ContentView` renders the Piano Sheets screen.
2. `PlayerViewModel` owns user-adjustable playback state.
3. `PianoSheetParser` converts text into `PianoSheetEvent` values.
4. `KeyboardSimulator` emits authorized macOS keyboard events.

## Safety Boundary

The app only simulates local keyboard input through macOS APIs. It must not inject code, inspect Roblox memory, patch files, bypass anti-cheat, or automate hidden behavior outside the user's active desktop session.

## Rhythm Auto Player (separate sidebar section)

- RhythmAutoPlayerView displays the independent rhythm interface.
- RhythmAutoPlayerViewModel coordinates lifecycle, per-instrument calibration, and safe keyboard output.
- RhythmCaptureService captures a Roblox window or display with ScreenCaptureKit, samples BGRA on a serial queue, and publishes previews.
- RhythmVisionDetector in Core tracks magenta (configurable HSV) moving circles, estimates their vertical motion, and emits lane keys when they approach a calibrated receptor.
- Keyboard events are emitted by KeyboardSimulator, and only while Roblox is in the foreground.
- ContentView is the sidebar host. Switching to Piano Sheets stops rhythm capture.
- SmokeTests/main.swift covers stationary/moving synthetic notes and instrument mappings as well as the existing sheet parser.

Image processing relies on the visible desktop session and screen recording permission. It does not inspect game internals. Live latency, note colors and camera movement need manual calibration.
