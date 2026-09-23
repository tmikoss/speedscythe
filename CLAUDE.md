# Speedscythe

Native macOS menu bar app (Swift, SwiftUI inside AppKit) that starts or continues Harvest timers with a hotkey and two digits.

The full spec and build order is in `docs/PLAN.md`. Read it before writing code. UI sketches are in `docs/sketches/` (look at the PNGs; the HTML files hold the exact sizes and colors).

## Working rules
- Build one milestone at a time, in the order in `docs/PLAN.md` §9. Check off a milestone in PLAN.md once its acceptance checks pass, and record spike results in §8.
- If a decision in PLAN.md turns out to be wrong or blocked, stop and ask. Don't silently redesign.
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
