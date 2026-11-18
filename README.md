# AutoTyper V2

A typing studio for macOS and Chrome. Paste your text, choose a rhythm, and let AutoTyper enter it at your chosen pace.

## Two ways to type

| | Mac app | Chrome extension |
|---|---|---|
| Destination | The currently focused app | One selected browser tab |
| Work elsewhere during typing | Keep the destination focused | Switch tabs or use another app |
| Setup | macOS Accessibility permission | Load the companion extension in Chrome |
| Emergency stop | Control–Option–Command–Escape | Command–Shift–Y on Mac; Ctrl–Shift–Y elsewhere, while Chrome is active |

## Features

- **Adjustable speed:** 15–150 WPM, with varied character timing and short bursts.
- **Five-second countdown:** time to prepare before typing begins.
- **Optional mistakes and repairs:** nearby-key slips followed by Backspace corrections, with adjustable frequency.
- **Natural pauses:** optional breaks around punctuation and paragraphs.
- **Session controls:** progress, approximate duration, pause, resume, and stop.
- **Background browser typing:** the extension locks onto one tab and editor, so switching tabs does not redirect your text.
- **Destination checks:** browser sessions stop when the tab closes, reloads, navigates, or loses its editor.
- **Local drafts:** extension drafts last for the browser session. No AutoTyper account or server is required. Text is delivered to the destination app or website you choose.

## Mac app

Open `AutoTyper.app` in Applications or use the Desktop shortcut. On the first run, enable AutoTyper in **System Settings → Privacy & Security → Accessibility**.

1. Paste your text and adjust the speed, mistakes, and pauses.
2. Click **Start typing**.
3. During the five-second countdown, click the destination text field.
4. Keep that app and field focused until the run finishes.

To build from source, install Apple's command line tools, then run:

```sh
./scripts/build.sh
open dist/AutoTyper.app
```

The app requires macOS 14 or newer. The build uses the architecture of the Mac running it.

## Chrome extension

Requires Chrome 118 or newer.

1. Open `chrome://extensions` and enable **Developer mode**.
2. Click **Load unpacked** and select this project's `browser-extension` folder.
3. Pin AutoTyper to the toolbar.
4. Open your destination page and click the insertion point, with no text selected.
5. Click the AutoTyper toolbar icon to open the browser studio.
6. Confirm the destination, paste your text, choose your settings, and click **Start in 5 seconds**.
7. Switch to another tab or app. Keep the destination tab open, Chrome running, and your computer awake.

Use **Pause**, **Resume**, or **Stop** in the studio. Chrome's debugger banner also lets you end the connection. Configure the extension's stop shortcut at `chrome://extensions/shortcuts` if the default conflicts with another shortcut.

After changing extension files, click **Reload** on its card at `chrome://extensions`, then reopen the studio.

## Compatibility and permissions

The Mac app sends plain-text keyboard input to the foreground app. Return may submit a message in chat fields. Destination autocorrect, formatting, or editor shortcuts can change the result.

The extension uses Chrome's debugger permission to send input directly to the chosen tab. Chrome displays a debugging banner during the session. Standard text fields and editable page regions are supported; Google Docs support is experimental and should be checked with a short sample in a blank document. Password fields, read-only fields, browser settings pages, and cross-origin iframe editors are unsupported. Opening DevTools on the destination may interrupt a session.

Avoid moving the cursor or editing the destination during a run. Stopping during a correction can leave a partial word or typo; inspect the result before restarting. Browser progress counts delivered operations and does not confirm that a document has saved to its server.

## Project layout

- `Sources/AutoTyper.swift` — native app interface and typing engine.
- `browser-extension/` — browser studio, background worker, and typing engine.
- `scripts/build.sh` — builds `dist/AutoTyper.app`.

## Interface and app icon

Version 0.3 introduces a light writing canvas, a dark sidebar, a dedicated settings panel, and persistent session controls. Choose **Relaxed**, **Balanced**, or **Quick** to set the typing speed, then adjust it with the slider. The Mac app and Chrome extension share an orange A-and-cursor icon.

After updating, quit and reopen the Mac app. In Chrome, reload the extension at `chrome://extensions`, close any old studio tabs, and reopen AutoTyper. The new sidebar displays **v0.3**. See [design and icon notes](docs/DESIGN.md) for asset generation and troubleshooting older copies.

## Accessibility enabled, but typing is still blocked

macOS grants permission to a specific signed app. An enabled entry can refer to an older build or another copy. AutoTyper now checks permission to post keyboard events without repeatedly showing the system prompt, and checks again when returning from Settings.

If the entry is stale:

1. Quit AutoTyper.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Select the old AutoTyper entry and remove it with **−**.
4. Use **+** to add `/Applications/AutoTyper.app`, then enable it.
5. Reopen the installed app and try Start again.

The build script signs and verifies the complete app bundle. By default it uses a local ad hoc signature; macOS may require permission again after a rebuild. To retain a certificate-backed identity across updates, configure a code-signing certificate and build every release with the same identity:

```sh
AUTOTYPER_SIGNING_IDENTITY="Your signing identity" ./scripts/build.sh
```

The app cannot grant its own Accessibility permission or silently transfer an older build's approval.
