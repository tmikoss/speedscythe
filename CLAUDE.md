# Speedscythe

Native macOS menu bar app (Swift, SwiftUI inside AppKit) that starts or continues Harvest timers with a hotkey and two digits.

## Working rules
- Prefer boring, maintainable code over clever code. The only third-party dependency is KeyboardShortcuts; ask before adding another.
- Never commit secrets or tokens. The OAuth client ID is public and fine to commit; there is no client secret.
- Never call the real Harvest API from automated tests.

## Commands
```sh
brew install xcodegen                 # once
xcodegen generate                     # after changing project.yml or adding/removing files
xcodebuild -scheme Speedscythe -destination 'platform=macOS' build
xcodebuild -scheme Speedscythe -destination 'platform=macOS' test
```
Never hand-edit `Speedscythe.xcodeproj`; it is generated, so change `project.yml` instead. Keep the generated project out of git.

## Code conventions
- Swift 6 toolchain, Swift 5 language mode, macOS 14 deployment target.
- `@MainActor` on UI and state classes; `async`/`await` for networking.
- Pure logic (`SlotResolver`, `BoardState`, `TimerDecision`, `OAuthCallbackParser`) has no AppKit/SwiftUI imports and has unit tests.
- Name the Harvest task model `HarvestTask` (Swift's `Task` is taken).
- Use system semantic colors plus the four accent color sets defined in PLAN.md §4.5.
