# Speedscythe — implementation plan

A native macOS menu bar app that starts or continues Harvest timers with a hotkey and two keystrokes.
Open source, no backend, all API traffic and data stays on the user's Mac.

The product name is "Speedscythe". Keep "Harvest" out of the product name (use "for Harvest" in descriptions).

Sketches of the picker live in `docs/sketches/` (PNG to look at, HTML for exact values). They are the source of truth for layout and states.

---

## 0. Before you start (needs the human)

These block milestone M1. Ask Toms for them if they are missing, don't invent values.

1. **Harvest OAuth app.** Register at https://id.getharvest.com/developers:
   - Name: Speedscythe
   - Redirect URL: `http://127.0.0.1:47823/callback` (Harvest rejected `speedscythe://oauth-callback`, see spike S1)
   - Multi account: **no** (single account)
   - Products: **Harvest** only
   - Client ID: `WxGxHAz8ykBWZi6ipb6e-MDX` (registered). The client ID is public by design; committing it is fine. There is no client secret in this app, ever.
   - The client ID, redirect URI, and User-Agent are build settings in `project.yml` (`HARVEST_CLIENT_ID`, `HARVEST_REDIRECT_URI`, `HARVEST_USER_AGENT`). Info.plist carries them to the app, and `Speedscythe/Config/HarvestOAuth.swift` reads them at runtime. To override them, change `project.yml` or pass them to `xcodebuild`.
2. **Bundle identifier:** `lv.mikoss.speedscythe` (decided).
3. **User-Agent:** `Speedscythe (https://github.com/tmikoss/speedscythe)` (decided). Harvest requires the application name and a link or email on every request; without it, requests fail with `400 Bad Request`.

---

## 1. Locked decisions

| Area | Decision |
|---|---|
| Platform | macOS 14+, universal binary (arm64 + x86_64) |
| Language/UI | Swift, SwiftUI views hosted in AppKit (`NSPanel`, `NSStatusItem`, `NSWindow`) |
| App type | Agent app (`LSUIElement = YES`): no Dock icon, menu bar item only |
| Project generation | XcodeGen (`project.yml`). Never hand-edit `.xcodeproj`; regenerate it |
| Dependencies | Only `sindresorhus/KeyboardShortcuts` (SPM). Everything else is Apple frameworks |
| Auth | Harvest OAuth2 **implicit grant** in the default browser, with a loopback redirect to a local `NWListener` (§6.1). No refresh token exists in this flow; user re-connects when the token expires |
| Token storage | Keychain (generic password) |
| Picker UI | "Board": all N slot projects as columns, their tasks as tiles. See sketches |
| Keyboard | Hotkey opens → digit selects project → digit selects task → timer starts, panel closes |
| Stopping | Manual only (the stop shortcut in the panel, default ⌫, or the menu bar menu). Nothing ever stops a timer automatically |
| Theme | Follows system light/dark automatically |
| Distribution | Unsigned (ad-hoc signed) zip on GitHub Releases. No App Store, no notarization for now |
| Accounts | One Harvest account per install |

### Out of scope for v1
Editing other entry fields or deleting entries, offline queue, multiple accounts, auto-update, App Store sandboxing, **auto-tracking (phase 2, see §12)**.

---

## 2. Harvest API reference (what this app uses)

Docs: https://help.getharvest.com/api-v2/

Every request to `https://api.harvestapp.com/v2/...` sends:
```
Authorization: Bearer <access_token>
Harvest-Account-Id: <account_id>
User-Agent: Speedscythe (https://github.com/tmikoss/speedscythe)
Content-Type: application/json   (for bodies)
```

### Auth (implicit grant)
- Authorize URL: `https://id.getharvest.com/oauth2/authorize?client_id=<ID>&response_type=token&state=<random>&redirect_uri=<encoded redirect>`
- The `redirect_uri` must start with the Redirect URL registered on the OAuth app.
- The callback carries `access_token`, `token_type` (always `bearer`), `expires_in` (seconds), `state`, `scope`.
  Parse parameters from **both** the URL fragment and the query string; implicit grant normally uses the fragment.
- `scope` for a single-account app is `harvest:<ACCOUNT_ID>`. Take the account ID from there. If the scope is instead `harvest:all` / `all`, call `GET https://id.getharvest.com/api/v2/accounts` (no account header needed) and use the first account with `product == "harvest"`.
- Validate `state` against the value you generated. Reject on mismatch.

### Endpoints
| Purpose | Call | Notes |
|---|---|---|
| Current user | `GET /v2/users/me` | Store `id`, name. Needed because time-entry queries must pass `user_id` |
| Account mode | `GET /v2/company` | Read `wants_timestamp_timers` (duration vs start/end tracking). Store it; log it. Timer calls below work in both modes |
| Projects + tasks | `GET /v2/users/me/project_assignments` | Active assignments only. Each has `project`, `client`, `task_assignments[]` (use `is_active` ones). Cursor-based pagination; `per_page` up to 2000 is plenty |
| Today's entries | `GET /v2/time_entries?user_id=<me>&from=<today>&to=<today>` | **Always pass `user_id`.** Admins otherwise get everyone's entries |
| Recent usage | `GET /v2/time_entries?user_id=<me>&from=<today-30d>` | Used to rank recent projects |
| Running timer | `GET /v2/time_entries?user_id=<me>&is_running=true` | |
| Start timer | `POST /v2/time_entries` body `{project_id, task_id, spent_date}` | Omitting `hours` (duration accounts) or `ended_time` (timestamp accounts) creates a running timer. Send only these three fields; it works in both modes |
| Continue entry | `PATCH /v2/time_entries/<id>/restart` | Only works on a stopped entry. **Use the returned entry**: in timestamp-mode accounts the response can be a *new* entry with a different `id` |
| Stop timer | `PATCH /v2/time_entries/<id>/stop` | Only works on a running entry |
| Update notes | `PATCH /v2/time_entries/<id>` body `{notes}` | Returns the full entry. Works on a running entry (checked in M5b); the docs do not say so |

`spent_date` is the user's **local** calendar date, `yyyy-MM-dd`.

### Rate limits and errors
- Treat the limit as roughly 100 requests per 15 seconds per token (verify in the docs). This app is far below it. On `429`, honor `Retry-After`.
- `401` → token expired or revoked → switch to *disconnected* state (§6.4).
- `403` / `404` / `422` → show the message from the response body in the panel's error banner.

### Name collision warning
Swift's concurrency `Task` type collides with a Harvest "task" model. Name the model `HarvestTask`.

---

## 3. Architecture

```
┌────────────────────── Speedscythe.app (LSUIElement) ──────────────────────┐
│                                                                            │
│  HotkeyService ──opens──▶ PanelController ──hosts──▶ BoardView (SwiftUI)    │
│  (KeyboardShortcuts)       (NSPanel)                   ▲                   │
│                              │ key events               │ observes         │
│                              ▼                          │                  │
│                          BoardState  ──actions──▶ TimerService             │
│                          (state machine)              │                    │
│                                                       ▼                    │
│  StatusItemController ◀──observes── AppStore ◀── HarvestClient ◀── Auth   │
│  (NSStatusItem)                     (@Observable)     (URLSession)  Service│
│                                       │  ▲                                  │
│  SettingsWindowController ──edits──▶ Preferences   CacheStore (JSON file)  │
│                                     (UserDefaults)  KeychainStore          │
│                                                                            │
│  SlotResolver (pure function: pins + recents + previous slots → slots)      │
└────────────────────────────────────────────────────────────────────────────┘
```

Rules:
- `TimerService` is the **only** thing that starts, continues, or stops timers. The panel calls it; phase 2 auto-tracking will call the same methods. Keep UI concerns out of it.
- `SlotResolver` and `BoardState` are pure and fully unit-tested. No AppKit imports in them.
- UI-facing classes are `@MainActor`. Network calls are `async`.
- Use Swift 6 toolchain with the Swift 5 language mode to avoid strict-concurrency churn; keep code warning-free.

### Folder layout
```
project.yml
Speedscythe/
  App/            SpeedscytheApp.swift (NSApplicationDelegateAdaptor), AppDelegate.swift
  Config/         HarvestOAuth.swift (clientID, redirectURI, userAgent)
  Models/         Project.swift, HarvestTask.swift, TimeEntry.swift, ProjectAssignment.swift, AuthSession.swift
  Services/       AuthService.swift, HarvestClient.swift, TimerService.swift, AppStore.swift,
                  CacheStore.swift, KeychainStore.swift, Preferences.swift, HotkeyService.swift
  Board/          BoardState.swift, SlotResolver.swift, BoardModel.swift (view-ready columns/tiles)
  Panel/          PickerPanel.swift (NSPanel subclass), PanelController.swift,
                  BoardView.swift, ProjectColumnView.swift, EditSlotView.swift, TaskTileView.swift, KeyCapView.swift, PanelHeaderView.swift
  StatusItem/     StatusItemController.swift
  Settings/       SettingsWindowController.swift, SettingsView.swift, AccountTab.swift, GeneralTab.swift
  Resources/      Assets.xcassets (color sets, app icon), Info.plist, Speedscythe.entitlements
SpeedscytheTests/
  SlotResolverTests.swift, BoardStateTests.swift, TimerDecisionTests.swift,
  OAuthCallbackParserTests.swift, DecodingTests.swift, Fixtures/*.json
docs/
  PLAN.md, sketches/
.github/workflows/  ci.yml, release.yml
README.md  LICENSE (MIT unless told otherwise)
```

### Info.plist / entitlements
- `LSUIElement = YES`
- `CFBundleURLTypes` with scheme `speedscythe`. OAuth does not use it (the loopback redirect replaces it, see S1). Phase 2 uses it for `speedscythe://context` (§12), so add it then
- App Sandbox **off**. Hardened runtime not required for ad-hoc builds.
- `MACOSX_DEPLOYMENT_TARGET = 14.0`

---

## 4. The picker panel

Sketches: `01-dark-open.png`, `02-dark-project-selected.png`, `03-light-open.png`, `04-light-project-selected.png`.
Sample names and times in the sketches are placeholders.

### 4.1 Window behavior (`PickerPanel: NSPanel`)
- Style mask: `[.nonactivatingPanel, .borderless]` (or `.titled` + `.fullSizeContentView` with a hidden title bar if borderless fights you). `isFloatingPanel = true`, `level = .floating`.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` so it appears over full-screen apps.
- Override `canBecomeKey → true`, `canBecomeMain → false`. `hidesOnDeactivate = false`.
- Background: `NSVisualEffectView` (material `.hudWindow` or `.popover`, `state = .active`), corner radius 20, `isOpaque = false`, `backgroundColor = .clear`, shadow on.
- **Create the panel once at launch and keep it.** Showing = reposition + `makeKeyAndOrderFront(nil)`. Target: visible within ~50 ms of the hotkey.
- Position: centered on the screen containing `NSEvent.mouseLocation`, using that screen's `visibleFrame`.
- Because the panel is non-activating, the previously active app stays active; dismissing the panel leaves focus where it was. Do not call `NSApp.activate` for the panel.
- Hide on: Esc at top level, successful timer start, `windowDidResignKey` (click outside), hotkey pressed again (toggle).
- Every show resets `BoardState` to `.idle`. "Edit board…" in the menu bar menu shows the panel in `.editing` (§4.7).

### 4.2 Layout
- Padding 28 pt; header row 40 pt; 20 pt gap; then the column grid.
- Columns: one per slot (N in 4–9, default 6). Column width ~164 pt, gap 8 pt. Panel width = columns + gaps + padding, at least the width of 4 columns, clamped to `visibleFrame.width - 80`; if clamped, shrink columns (min ~120 pt).
- Column: 8 pt inner padding, 16 pt radius. Header = key cap + project name (15 pt semibold). If two visible projects share a name, append the client name in secondary text.
- Tile: height 88 pt, radius 12, 12 pt padding. Top row: key cap (left) + status text (right). Bottom: task name (15 pt medium).
- **Tasks:** show all active task assignments. A project with a saved task order (§4.7) shows those tasks first, in the saved order, then the other tasks in API order. Otherwise use the order the API returns (see spike S6). Tasks 1–9 get key caps; tasks 10+ get no key cap and are click-only.
- **Overflow:** a column shows at most 6 tiles, then scrolls vertically inside itself (`ScrollView`). Panel height follows the tallest column up to that cap. Shorter columns pad with faint dashed placeholders up to the tallest column's visible tile count, as in the sketches.
- When keyboard selection targets a tile below the fold, scroll it into view.

### 4.3 Header
- Left: running indicator (accent dot, "Running", `Project · Task`, the notes of the entry, elapsed `h:mm:ss` ticking every second while visible). No running timer → secondary text "No timer running".
- The notes are secondary text on one line. They truncate first, so the elapsed time stays visible. They hide while the notes field shows (§4.8).
- Right: a pencil button that toggles edit mode (§4.7), and a "Stop timer" button with a key cap that shows the stop shortcut (default `⌫`). The Stop button is disabled when nothing is running. In edit mode, − and + buttons appear before the pencil button.
- The hint text (changes by state, exact strings in sketches) is centered below the column grid, not in the header. The sketches show it in the header; the header was too narrow for it.
- Error banner slot below the header (hidden normally). Also used for "Harvest connection expires soon — Reconnect" (§6.4).

### 4.4 Tile states
| State | Look (dark / light) |
|---|---|
| Idle | Standard tile |
| Running | Accent fill + accent border, elapsed time in accent (top right) |
| Has an entry today | Teal "h:mm" top right. Selecting it continues that entry (if the setting is on) |
| Column selected (after project digit) | Column gets a subtle fill + border; its key caps invert (solid); other columns dim to ~35–40% opacity |
| Starting | Tile shows a small spinner in place of status text; input ignored until it resolves |
| Hover | Slightly raised fill |

### 4.5 Colors
Use system semantic colors for neutrals (`labelColor`, `secondaryLabelColor`, `separatorColor`, `controlBackgroundColor`, etc.) so light/dark is automatic. The sketches' neutral hex values are only a guide.

Add these color sets to `Assets.xcassets` with Any/Dark variants:

| Name | Light | Dark | Use |
|---|---|---|---|
| `RunningAccent` | `#D98B1A` | `#F0A843` | dot, running border |
| `RunningText` | `#9A5A00` | `#F0A843` | elapsed time text |
| `RunningFill` | `#FFF3DF` | `#3A2F1C` | running tile fill |
| `TodayText` | `#1E7F74` | `#5CC2B5` | today's "h:mm" |

Text contrast must stay ≥ 4.5:1 in both themes.

### 4.6 Empty and error states (inside the panel)
- **Not connected:** centered message "Connect your Harvest account to start timers", the last error (for example after a `401`), and buttons "Connect" (runs `connect()`) and "Open Settings". While the browser flow runs, "Waiting for Harvest in your browser…" replaces the error.
- **Connected, cache empty, first fetch in flight:** "Loading projects…".
- **Connected, cache empty, first fetch failed:** "Speedscythe cannot load your projects", the error, and a "Try Again" button.
- **No project assignments:** "No projects are assigned to you in Harvest."
- **Start/stop failed:** banner with the API error message; panel stays open.
- **Refresh failed while cached data shows:** the same banner with the refresh error.
- In all states except the board, the header hides the pencil button.
- While the panel is visible, PanelController tracks the board, the content state, and the error messages with `withObservationTracking`. When one changes, the panel resizes and stays centered.

### 4.7 Edit mode
The user edits the board layout in the panel, not in Settings.
- Enter: the pencil button in the header, or "Edit board…" in the menu bar menu. Leave: the pencil button again, or Esc.
- The grid shows one column for each slot (N), also for empty slots. Digits and tile clicks do nothing. The stop shortcut still stops the timer.
- A pinned slot shows its project name, a clear button (`xmark.circle.fill`), a subtle fill, and a solid border. An unpinned slot shows the recent project that fills it now (or "Recent"), a dashed border, and dimmed tiles.
- A click on a column opens an `NSMenu` with all active projects, grouped by client under section headers. The current pin has a check mark. Projects pinned in other slots are disabled.
- A column with more than 6 tasks scrolls in edit mode too (scroll wheel or trackpad), and all its tasks can be dragged. A drag past the visible area keeps moving the target row. The scroll view does not scroll automatically during a drag.
- In a pinned column, each task tile shows a drag handle (`line.3.horizontal`) in place of the key cap. Drag a task tile up or down to change the task order. The other tiles move aside during the drag. The app saves the order for each project, and the order applies in every slot that shows the project. Tasks that Harvest adds later go after the saved order. A click on a tile without a drag opens the project menu.
- − removes the last column and clears its pin. + adds a column. N stays in 4–9.
- After each change, the panel resizes and stays centered.

### 4.8 Notes editing
The user sets the notes of the running entry in the panel.
- Enter: the notes shortcut (`KeyboardShortcuts.Name.editNotes`, default `N`) in `idle` or `projectSelected`. The shortcut does nothing when no timer runs, in edit mode, or while a timer starts.
- A full-width single-line text field shows below the header. It contains the current notes, with newlines changed to spaces, and has keyboard focus. The columns dim to 38% opacity and ignore clicks.
- Enter saves the notes and closes the panel. Esc discards the draft and goes back to the board.
- While the save runs, the field is disabled and the hint shows "Saving notes…". If the save fails, the error banner shows the message, and the field keeps the draft.
- The save goes to the entry that ran when the user pressed the shortcut. If that timer stops during typing, the notes still go to that entry.
- The idle hint adds "· N notes" (the current shortcut) while a timer runs.

### 4.9 Last task
The user starts the last task again with one key in the panel.
- The shortcut is `KeyboardShortcuts.Name.startLastTask`, default `T`. It works only in the panel, in the same way as the stop and notes shortcuts.
- The last task is the task of the most recently updated recent entry of an active project. When a timer runs, the app skips entries with the task of the running entry. Thus, `T` switches back to the task before the running one.
- The tile of the last task shows a second key cap with the shortcut, after the task number.
- If no tile shows the last task, the shortcut still starts it. No key cap shows in this case.
- The shortcut does nothing when no recent entry qualifies.

---

## 5. Keyboard and mouse

Handle keys with an `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` monitor that is installed while the panel is visible and routes into `BoardState`. (SwiftUI focus inside non-activating panels is unreliable; don't depend on `onKeyPress` for this.) Accept top-row digits and keypad digits. Ignore unmapped keys silently.

### BoardState machine
```
            hotkey
  closed ──────────▶ idle ──digit p (1…N, column exists)──▶ projectSelected(p)
    ▲                 │  ▲                                        │
    │   Esc           │  └──────────────── Esc ───────────────────┤
    └─────────────────┘                                           │
    ▲                                                   digit t (1…9, task exists)
    │                                                             ▼
    └──────────── success ◀──── starting(p, t) ◀─────────────────┘
                                   │ failure → idle + error banner
```
- In `projectSelected`, digits select **tasks**, not projects. To switch project: Esc, then the other digit.
- A project with one task still waits for its task digit (consistent two-key rhythm).
- The stop shortcut in any open state → `TimerService.stop()`. It is `KeyboardShortcuts.Name.stopTimer`, default `⌫`. No handler is attached to it, so it is never a global hotkey. The key monitor compares each key event with it. The panel buttons are not focusable, so Space and Return never press them.
- The pencil button toggles `editing` from `idle` or `projectSelected`. In `editing`, Esc or the pencil button goes back to `idle`, and digits and clicks do nothing (§4.7).
- The notes shortcut goes from `idle` or `projectSelected` to `editingNotes` while a timer runs (§4.8). In `editingNotes`, Esc goes back to `idle`, and Return or keypad Enter goes to `savingNotes`. `savingNotes` goes to `idle` and closes the panel on success, or back to `editingNotes` on failure. Both states ignore all other events, including the stop shortcut.
- In `editingNotes`, the key monitor consumes only Esc, Return, and keypad Enter. All other keys go to the text field. This is necessary because the stop shortcut is plain `⌫`, which the user also needs to delete text. In `savingNotes`, the key monitor consumes all keys.
- The last-task shortcut starts the last task from `idle` or `projectSelected` (§4.9). If the task has a tile, the state goes to `starting(p, t)`. If not, it goes to `startingOffBoard`, which acts like `starting` without a tile spinner. Edit mode, the notes states, and both starting states ignore the shortcut.
- `/` → search (M6, optional; see §9).
- Mouse: clicking any tile starts it from any state. Clicking a column header = pressing its digit.

Write `BoardState` as a pure reducer `(state, event, boardModel) -> (state, effect?)` so it is trivially testable.

---

## 6. Services

### 6.1 AuthService
- `connect()` (loopback flow, because S1 failed): generate random `state`, build the authorize URL with `redirect_uri = http://127.0.0.1:47823/callback`, start an `NWListener` on that port, and open the authorize URL in the default browser. The token arrives in the fragment, which browsers never send to servers, so serve a tiny HTML page whose script POSTs `location.hash` to `/token` on the same listener. Then close the listener. The default browser keeps its Harvest session, so reconnects can reuse it (S7).
- On callback: parse (fragment + query), validate `state`, extract token, `expiresAt = now + expires_in`, account ID from `scope`.
- Save `AuthSession {accessToken, expiresAt, accountId}` as JSON in Keychain (service = bundle ID, account = `harvest-oauth`).
- Then fetch `/users/me` and `/company`, store user ID, name, and timestamp mode in the cache.
- `disconnect()`: delete the Keychain item and cache, return to *not connected*.

### 6.2 HarvestClient
- Thin `async` wrapper over `URLSession` with typed request/response methods for each endpoint in §2.
- `JSONDecoder` with snake_case conversion. Dates: `spent_date` as `yyyy-MM-dd`, timestamps ISO 8601.
- Maps HTTP errors to a small `HarvestError` enum (`unauthorized`, `rateLimited(retryAfter)`, `api(status, message)`, `network`).
- Decoding tests use fixture JSON copied from the docs' examples.

### 6.3 AppStore + CacheStore + refresh policy
`AppStore` (`@Observable`, `@MainActor`) holds: auth status, user, assignments, today's entries, running entry, recent project order, last refresh time, current error.

`CacheStore` persists everything except the token to `~/Library/Application Support/<bundle id>/cache.json`. Load it at launch **before** any network call, so the panel can render instantly.

Refresh (all in the background; the UI updates when data arrives, never blocks):
- At launch.
- On panel open, if the last refresh is older than 30 s.
- Every 5 minutes.
- Immediately after any start/continue/stop.
- On wake (`NSWorkspace.didWakeNotification`) and on day change (`.NSCalendarDayChanged`, which also clears today's entries).

Elapsed time for the running entry: `hours` at fetch time + (now − fetch time). This works in both tracking modes.

**Recent project order:** from the last 30 days of the user's entries, take each project's most recent `updated_at`, sort descending, keep only projects that are still actively assigned.

### 6.4 Token expiry
- `expiresAt − now < 24 h` → header banner "Harvest connection expires soon — Reconnect" (click runs `connect()`), and the Settings Account tab shows the same.
- Any `401`, from a refresh or from a timer start or stop, → `AppStore.sessionRejected()` → *disconnected* state: panel shows the not-connected screen with a "Reconnect" button; the menu bar item shows a warning symbol.

### 6.5 TimerService
Public API (phase 2 will reuse it):
```swift
func start(projectID: Int, taskID: Int, source: StartSource) async throws   // .picker, later .autoTracking
func stop() async throws
func updateNotes(entryID: Int, notes: String) async throws
```
`updateNotes` sends `PATCH /time_entries/<id> {notes}` and updates the store from the returned entry. It does not trigger a refresh, because the response is the full entry.

`start` logic:
1. If the running entry already has this project + task → do nothing (success).
2. Else, if Preferences.continueToday is on and today has a **stopped, unlocked** entry with this project + task → `PATCH restart` on the most recently updated one.
3. Else → `POST /time_entries {project_id, task_id, spent_date: today}`.
4. Whether Harvest auto-stops the previously running timer is spike S4. If it doesn't, stop the running entry first.
5. Update the store from the returned entry (remember that restart may return a new ID), then trigger a refresh.

Extract steps 1–3 into a pure `TimerDecision` function and unit-test it.

### 6.6 SlotResolver (pure, heavily tested)
Inputs: `pinned: [Int: ProjectID]` (slot index → project, set in edit mode), `n: Int`, `recentOrder: [ProjectID]` (most recent first), `previousRecentSlots: [Int: ProjectID]` (slot index → project, persisted), `activeProjects: Set<ProjectID>`.

Algorithm:
1. Each pin with an index in `0..<n` and an active project takes its slot. If one project has two pins, only the lower index counts.
2. The other slots are recent slots (`k` of them). `R` = the first `k` projects of `recentOrder` that are active and not pinned.
3. For each previous recent slot index that is still a recent slot, if its project is in `R`, keep it at the same index.
4. Fill the empty recent slots in ascending index with the remaining members of `R`, in recency order.
5. If fewer projects than `n` exist, the leftover slots are empty and the panel renders fewer columns.
6. Return the slots plus the new `previousRecentSlots` to persist.

Effect: a pinned project never moves. A recent project keeps its number until it drops out of the top `k`; a newcomer takes the vacated slot. Numbers never reshuffle because of ordering alone.

Required tests: pinned projects keep their slots and recents fill the rest; pins at or above n are ignored; a newcomer replaces the least recent at the same index; stable output when nothing changes; archived pins leave the slot to recents; a pinned project is not repeated as recent; a duplicate pin; fewer projects than n; n shrinking and growing.

### 6.7 StatusItemController
- Idle: the `MenuBarIcon` template image only (the app icon dial with the scythe needle, in one color; macOS tints it).
- Running: symbol + elapsed `h:mm` (update every 30 s; exact seconds aren't needed in the menu bar).
- Disconnected or error: `exclamationmark.triangle`.
- Menu: running entry line (`Project · Task`, disabled), "Stop timer", separator, "Open picker" (shows the current hotkey), "Edit board…", "Settings…", separator, "Quit Speedscythe".

### 6.8 HotkeyService
`KeyboardShortcuts.Name.openPicker`, default `⌃⌥T` (user-changeable; avoids common app shortcuts like ⌥⌘T). `onKeyUp` → toggle the panel.

---

## 7. Settings window

A regular `NSWindow` hosting SwiftUI (not the `Settings` scene, which is awkward in agent apps). Opening it calls `NSApp.activate()` (the macOS 14 API) so the window comes to the front.

The layout follows System Settings: a `NavigationSplitView` with a sidebar of panes on the left and the selected pane on the right. Each pane is a `.formStyle(.grouped)` form. The hosting controller sets `sceneBridgingOptions = .all`, so the pane title shows in the unified toolbar. Panes:

- **Account:** "Harvest" section with "Connected as <name> · <account>", "Connection expires" (relative date), a warning when less than 24 h remain (§6.4), and buttons Connect, or Disconnect and Reconnect.
- **General:**
  - "Shortcuts" section: "Open picker", "Stop timer in the panel", "Edit notes in the panel", and "Start the last task in the panel" (`KeyboardShortcuts.Recorder` for `.openPicker`, `.stopTimer`, `.editNotes`, and `.startLastTask`), and a "Reset shortcuts" button. The button resets all four shortcuts to their defaults. The Recorder accepts only shortcuts with a modifier, and ⌫ in the Recorder clears the shortcut. The button is the only way back to the plain `⌫` default.
  - "Timers" section: toggle "Continue the matching entry from today" (default on), with the subtitle "Off: every start creates a new entry."
  - "Startup" section: "Launch at login" via `SMAppService.mainApp` (spike S8). If the status is `.requiresApproval`, a note tells the user to allow Speedscythe in System Settings → General → Login Items. A `register()` or `unregister()` error shows below the toggle.

The user sets the slot count and the pinned projects in the panel edit mode (§4.7), not in Settings.

Preferences live in `UserDefaults` (`slotCount` default 6, `continueToday`, `pinnedSlots`, `taskOrders`, `recentSlotAssignments`). KeyboardShortcuts stores its own.

---

## 8. Spikes to run early (log results in this file)

| # | Question | When | How |
|---|---|---|---|
| S1 | Does Harvest accept `speedscythe://oauth-callback` as a Redirect URL? | Before M1 (human) | Try registering it. If rejected, use the loopback fallback (§6.1). **Result: rejected.** The app uses the loopback redirect `http://127.0.0.1:47823/callback` |
| S2 | Are callback params in the fragment or the query? | M1 | Log the raw callback URL once (redact the token). **Result: query string**, e.g. `/callback?access_token=…&expires_in=…&scope=harvest%3A<ID>&state=…&token_type=bearer`, although the docs say fragment. The parser reads both |
| S3 | Actual token lifetime (`expires_in`) | M1 | Log it. **Result: 1209599 s (14 days)** |
| S4 | Does starting or restarting a timer auto-stop the currently running one? | M4 | Start A, then start B, then list running entries. **Result: yes.** After each start only the new entry was running, so TimerService does not stop the running entry first |
| S5 | Restart behavior in this account's mode: same ID or new entry? | M4 | Restart a stopped entry, compare IDs, check the web UI. **Result: same ID** in this duration-mode account (`wants_timestamp_timers: false`). Timestamp mode is not tested; TimerService uses the returned entry in both modes |
| S6 | Is the `task_assignments` order stable across fetches? | M2 | Fetch twice, compare. If unstable, sort tasks by name (case-insensitive). **Result: stable** (0 of 28 assignments changed task order between two fetches). Use the API order |
| S7 | Does reconnect skip Harvest's login/consent when the browser session is alive? | M6 | Disconnect, then Connect |
| S8 | Does `SMAppService.mainApp` work with ad-hoc signed builds? | M6 | If not, drop the toggle and document manual Login Items setup in the README |

---

## 9. Milestones (build in this order)

Each milestone ends with tests passing, the app running, and the acceptance checks done by hand. Check the boxes as you go.

- [x] **M0 — Skeleton + CI**
  XcodeGen project, agent app with a menu bar item (Quit only), empty test target, `ci.yml` building and testing on push.
  *Accept:* `xcodegen generate && xcodebuild test` passes locally and in CI; no Dock icon; Quit works.

- [x] **M1 — Connect to Harvest**
  Settings window (Account tab), AuthService, KeychainStore, HarvestClient `/users/me` + `/company`, `OAuthCallbackParser` with tests.
  *Accept:* Connect opens Harvest login; afterwards Settings shows "Connected as <name>"; relaunching keeps you connected; Disconnect clears it. Record S2/S3.

- [x] **M2 — Data + cache**
  Project assignments, today's and recent entries, running entry; AppStore; CacheStore; refresh policy; decoding tests.
  *Accept:* after launch the cache file holds your projects/tasks; offline relaunch still loads them. Record S6.

- [x] **M3 — Panel (read-only)**
  PickerPanel, PanelController, HotkeyService, BoardView rendering from the cache using a simple provisional slot rule (first N projects by recency), light/dark, correct screen, Esc/click-outside/toggle to close.
  *Accept:* hotkey shows the board over any app, including a full-screen one, in under a blink; it matches the sketches in both themes; focus returns to the previous app on close.

- [x] **M4 — Start, continue, stop**
  BoardState machine with tests, TimerService + TimerDecision with tests, header running indicator, tile states, StatusItemController with live elapsed time and Stop.
  *Accept:* hotkey → 1 → 2 starts Project 1 / Task 2 in Harvest (check the web UI) and closes the panel; repeating it on a stopped entry today continues that entry; ⌘⌫ stops. Record S4/S5.

- [x] **M5 — Pinned slots and edit mode**
  SlotResolver with the full test list from §6.6; panel edit mode (§4.7); N slots.
  *Accept:* a pinned project always occupies its slot; − and + change the column count; recent columns only change number when a new project enters.

- [x] **M5b — Running entry notes**
  `notes` on `TimeEntry`, `PATCH /time_entries/<id>`, `TimerService.updateNotes`, the `editingNotes` and `savingNotes` states with tests, the notes field and header notes (§4.3, §4.8), and the "Edit notes in the panel" Recorder.
  *Accept:* with a timer running, the header shows its notes; N opens the field with the notes and the field has keyboard focus; typing and ⌫ edit the text and do not stop the timer; Esc goes back to the board; Enter saves and closes the panel, and the Harvest web UI shows the new notes on the running entry; N does nothing with no timer running or in edit mode; "Reset shortcuts" restores N.

- [ ] **M6 — Polish**
  Column overflow scrolling + tasks past 9 (§4.2), all empty/error states (§4.6), expiry banner + 401 handling (§6.4), launch at login, hover states. Optional: `/` search (a field that fuzzy-filters tiles by "project task" text; Enter starts the top match; Esc clears then closes).
  *Accept:* a project with 12 tasks scrolls inside its column, and tasks 10–12 are clickable; revoking the token in Harvest leads to the reconnect screen. Record S7/S8.

- [ ] **M7 — Release**
  `release.yml`: on tag `v*`, build Release universal (`ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO`), ad-hoc sign (`codesign --force --deep --sign - Speedscythe.app`), `ditto -c -k --keepParent Speedscythe.app Speedscythe-<version>.zip`, attach to a GitHub Release. README: install steps, Gatekeeper "Open Anyway" (System Settings → Privacy & Security), building from source, and a note that each update may re-prompt for Keychain access because ad-hoc signatures change.
  *Accept:* a downloaded zip from the release runs on a second Mac after "Open Anyway".

---

## 10. Testing

- Unit (XCTest or Swift Testing): SlotResolver, BoardState, TimerDecision, OAuthCallbackParser, model decoding against fixtures, elapsed-time formatting.
- `HarvestClient` behind a protocol so TimerService tests use a fake.
- No UI tests. Do manual acceptance per milestone.
- Never hit the real Harvest API in automated tests.

---

## 11. Things that will bite

- **Keychain prompts after every rebuild/update** with ad-hoc signing; expected. In development, sign with a stable local "Apple Development" identity (a free Apple ID in Xcode) to avoid them.
- **Non-activating panel + text input:** fine for key events via the local monitor. A SwiftUI `TextField` in the panel takes focus (M5b notes field) with two steps. PanelController calls `panel.makeFirstResponder(hostingView)`, because the first responder is otherwise the panel itself. The view then sets its `@FocusState` in a `Task`, because a focus change in the update that inserts the field has no effect. `.defaultFocus` does not work here.
- **Full-screen spaces:** without `.fullScreenAuxiliary` the panel opens on another space. Test with a full-screen app early.
- **Time zones:** `spent_date` and "today" use the local calendar, not UTC.
- **Locked entries** (`is_locked`) can't be restarted; TimerDecision must skip them.
- **Admins:** always pass `user_id` when listing entries.

---

## 12. Phase 2 preview (do not build yet)

Auto-tracking: context signals (frontmost app via `NSWorkspace`; terminal working directory via a shell hook that opens `speedscythe://context?cwd=…`, or AppleScript for Terminal/iTerm) are matched against user rules (e.g. path prefix `~/code/project-a` → Project A / Software development). A match calls `TimerService.start(..., source: .autoTracking)`. Auto-tracking only ever starts or switches timers, never stops them, and can be toggled off. Keep TimerService free of UI assumptions so this plugs in without touching the panel.

---

## 13. Decision log

Short record of why things are the way they are, so they don't get re-litigated.

- Board layout over a recents list or radial menu: stable positions build muscle memory; a radial menu's outer ring made mouse paths cross neighboring wedges.
- Two-step digits (project, then task) over a single-key keyboard map: easier to learn and scales to 9×9.
- Implicit grant over the authorization code flow: the code flow needs a client secret for both the exchange and refresh, which can't be kept secret in an open-source app. Revisit (secret injected by CI) if reconnecting gets annoying.
- Swift over Tauri: the hard parts are OS integration (panel, hotkey, focus, later Accessibility); the UI is one screen.
- Pinned slots plus in-place recent slots: a pinned project never moves; recent numbers change only when the set of projects changes.
- Edit mode in the panel over a Favorites tab in Settings: the user edits the board on the same grid that they use, so a pin goes to the exact slot number.
- Notes editing in the panel (a single-line field under the header, Enter saves and closes) over keeping notes out of scope: the user sets notes on the running entry without the Harvest web UI.
- All tasks shown, no per-project task filter: tasks past 9 are click-only; columns scroll past 6 tiles. The only per-project task setting is the order, which the user changes by drag in edit mode.
