# Speedscythe

A macOS menu bar app for [Harvest](https://www.getharvest.com). Speedscythe starts or continues a Harvest timer with a hotkey and two digits, from any app.

- Press `⌃⌥T`. A board with your projects and their tasks opens over the current app.
- Press a project digit, then a task digit. The timer starts, and the board closes.
- If you already have a stopped entry today for that task, Speedscythe continues that entry.
- Press `T` to go back to the task before the current one.

Speedscythe requires macOS 14 or later.

## Install

1. Download `Speedscythe-<version>.zip` from the [latest release](https://github.com/tmikoss/speedscythe/releases/latest).
2. Unzip it and move `Speedscythe.app` to `/Applications`.
3. Open `Speedscythe.app`. macOS blocks the app the first time, because the app has an ad-hoc signature and Apple did not notarize it. See [macOS blocks the app](#macos-blocks-the-app).

Speedscythe shows an icon in the menu bar. It has no Dock icon.

## Connect to Harvest

1. Click the menu bar icon and select "Settings…".
2. In "Account", click "Connect". Your browser opens the Harvest login page.
3. Log in and allow access. The browser tab tells you when Speedscythe is connected.

The connection is valid for 14 days. Speedscythe keeps the access token in your Keychain and sends data only to Harvest.

## Use the board

### Keys

| Key | Where | Action |
|---|---|---|
| `⌃⌥T` | Any app | Open or close the board |
| `1`–`9` | Board | Select a project column, then a task in that column |
| `T` | Board | Start the last task again |
| `N` | Board, while a timer runs | Edit the notes of the running entry |
| `⌫` | Board | Stop the running timer |
| Esc | Board | Go back one step, or close the board |
| Return | Notes field | Save the notes and close the board |

You can change `⌃⌥T`, `T`, `N`, and `⌫` in Settings. The board shortcuts (`T`, `N`, `⌫`) can be plain keys, but not digits, because the digits select projects and tasks.

You can also use the mouse. Click a tile to start its task. Click a column header to select that project. Click outside the board to close it.

### Tiles

- The tile of the running task has an orange border and shows the elapsed time.
- A teal time, for example `1:25`, shows how long you worked on that task today.
- The `T` key cap marks the last task. When a timer runs, the last task is the task you worked on before the running one.
- Tasks 1 to 9 have a digit key cap. Tasks 10 and higher have no key cap. Click them to start them.
- A column shows up to 6 tiles. Scroll in the column to see more.

### Notes

With a timer running, press `N`. A text field with the notes of the running entry opens. Press Return to save the notes and close the board, or press Esc to discard the change.

### Edit the board

Click the pencil button on the board, or select "Edit board…" in the menu bar menu.

- Click a column to pin a project to that column number. Click × to remove the pin.
- Columns without a pin show your most recent projects. A recent project keeps its number until a new project replaces it.
- Click − or + to change the number of columns (4 to 9).
- In a pinned column, drag a task tile up or down to change the task order.

### Menu bar

The menu bar icon shows the elapsed time of the running timer. Its menu shows the running task and has "Stop timer", "Open picker", "Edit board…", and "Settings…".

## Settings

- **Shortcuts:** change the hotkey and the three board shortcuts. "Reset shortcuts" sets all four back to their defaults.
- **Timers:** "Continue the matching entry from today" is on by default. When you start a task that already has a stopped entry today, Speedscythe restarts that entry. Turn it off to create a new entry every time.
- **Startup:** turn on "Launch at login".

## Troubleshooting

### macOS blocks the app

macOS blocks apps that Apple did not notarize. To open Speedscythe:

1. Open `Speedscythe.app` once and close the message.
2. Open System Settings → Privacy & Security.
3. Scroll down and click "Open Anyway" next to the message about Speedscythe.
4. Confirm when macOS asks again.

### macOS asks for Keychain access after an update

Each release has a new ad-hoc signature. Thus, after an update, macOS can ask again if Speedscythe can use its Keychain item. Click "Always Allow".

### The menu bar icon shows a warning triangle

Speedscythe is not connected, or the last request to Harvest failed. Open the board or "Settings…" to see the message.

- If the connection expired, click "Reconnect" in "Account". Speedscythe shows a warning on the board and in Settings one day before the connection expires.
- If Speedscythe cannot load your projects, click "Try Again" on the board.

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

To make a release, push a tag that starts with `v`, for example `v0.1.2`. The release workflow builds a universal app, signs it ad-hoc, and attaches the zip to a GitHub Release. The tag sets the app version.

## License

MIT. See [LICENSE](LICENSE).
