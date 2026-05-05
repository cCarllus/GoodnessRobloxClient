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
