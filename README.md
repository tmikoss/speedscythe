# Speedscythe

Speedscythe is a macOS menu bar app for [Harvest](https://www.getharvest.com). It starts or continues a Harvest timer with a hotkey and two digits.

- Press the hotkey (default `⌃⌥T`). A board with your projects and their tasks opens over the current app.
- Press a project digit, then a task digit. The timer starts, and the board closes.
- If you already have a stopped entry today for that task, Speedscythe continues that entry.
- Press `⌫` on the board to stop the running timer.

Speedscythe requires macOS 14 or later.

## Install

1. Download `Speedscythe-<version>.zip` from the [latest release](https://github.com/tmikoss/speedscythe/releases/latest).
2. Unzip it and move `Speedscythe.app` to `/Applications`.
3. Open `Speedscythe.app`. macOS blocks it, because the app has an ad-hoc signature and Apple did not notarize it.
4. Open System Settings → Privacy & Security. Scroll down and click "Open Anyway" next to the message about Speedscythe. Confirm when macOS asks again.

Speedscythe shows a timer icon in the menu bar. It has no Dock icon.

## Connect to Harvest

1. Click the menu bar icon and select "Settings…".
2. In "Account", click "Connect". Your browser opens the Harvest login page.
3. Log in and allow access. The browser tab tells you when Speedscythe is connected.

The connection is valid for 14 days. Speedscythe warns you one day before it expires. To connect again, click "Reconnect".

Speedscythe keeps the access token in your Keychain. It does not send data to any server other than Harvest.

## Use the board

- **Start a timer:** press the hotkey, then the project digit, then the task digit. You can also click a tile.
- **Change project:** click a column header, or press Esc and then another digit.
- **Stop the timer:** press `⌫` on the board, click "Stop timer", or use the menu bar menu.
- **Close the board:** press Esc, press the hotkey again, or click outside the board.

### Edit the board

Click the pencil button on the board, or select "Edit board…" in the menu bar menu.

- Click a column to pin a project to that column number. Click × to remove the pin.
- Columns without a pin show your most recent projects. A recent project keeps its number until a new project replaces it.
- Click − or + to change the number of columns (4 to 9).
- In a pinned column, drag a task tile up or down to change the task order.

### Settings

- **Shortcuts:** change the hotkey and the stop shortcut. "Reset shortcuts" sets both back to the defaults.
- **Timers:** "Continue the matching entry from today" is on by default. When you start a task that already has a stopped entry today, Speedscythe restarts that entry. Turn it off to create a new entry every time.
- **Startup:** turn on "Launch at login".

## Build from source

You need Xcode 26 or later (KeyboardShortcuts requires Swift tools 6.2) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
xcodebuild -scheme Speedscythe -destination 'platform=macOS' build
xcodebuild -scheme Speedscythe -destination 'platform=macOS' test
```

`xcodegen generate` creates `Speedscythe.xcodeproj` from `project.yml`. Run it again after you add or remove files. Do not edit the generated project.

The Harvest OAuth client ID, the redirect URL, and the User-Agent are build settings in `project.yml`.

`scripts/make-icons.swift` draws the app icon and the menu bar icon. To change an icon, edit the script and run `swift scripts/make-icons.swift` from the repository root. The script writes the PNG files into `Speedscythe/Resources/Assets.xcassets`.

To make a release, push a tag that starts with `v`, for example `v0.1.0`. The release workflow builds a universal app, signs it ad-hoc, and attaches the zip to a GitHub Release.

## Keychain prompts after an update

Each build has a new ad-hoc signature. After an update, macOS can ask again if Speedscythe can use its Keychain item. Click "Always Allow".

## License

MIT. See [LICENSE](LICENSE).
