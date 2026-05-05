# AGENTS.md

## Project

Goodness Roblox Client is a macOS SwiftUI app. Piano Sheets is one feature inside this project, not a separate product.

The app is for personal music practice, accessibility, and local automation. Keep the implementation limited to macOS keyboard events. Do not add injection, memory reading, Roblox modification, anti-cheat bypasses, or hidden background behavior.

## Architecture Rules

- `Sources/GoodnessRobloxClient` owns SwiftUI views and app state composition.
- `Sources/GoodnessRobloxClientCore` owns reusable domain logic, parsing, and keyboard simulation.
- UI code must not parse sheets directly. Route parsing through `PianoSheetParser`.
- UI code must not create raw `CGEvent` values directly. Route keyboard output through `KeyboardSimulator`.
- Keep feature logic small and explicit. Prefer structs/enums for values and final classes for stateful services.
- Preserve single responsibility: parsing, playback state, keyboard simulation, and layout should stay in separate files.
- Prefer dependency direction from app to core only. Core must not import SwiftUI.
- Do not add dependencies unless they remove meaningful complexity.

## SOLID Guidance

- Single Responsibility: one file should have one reason to change.
- Open/Closed: add new sheet behavior through parser options or new focused types, not by stuffing conditionals into views.
- Liskov: keep protocols small if introduced; do not use inheritance for app logic.
- Interface Segregation: expose narrow APIs such as parser input/options and keyboard chord output.
- Dependency Inversion: keep UI depending on abstractions or small services when behavior grows.

## Development Workflow

Run before handing off changes:

```sh
scripts/verify.sh
```

Package the app with:

```sh
scripts/package_app.sh
```

If generated files appear under `.build/` or `dist/`, leave them untracked.

## UX Rules

- Keep the main screen centered on `Piano Sheets`.
- Controls should be visible and direct: play, pause, stop, timing, hold duration, and delay.
- Avoid adding unrelated client features until there is a concrete feature request.
- Text should stay short and clear in Portuguese.
