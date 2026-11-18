<img src="browser-extension/icons/icon-128.png" alt="" width="64" height="64">

# AutoTyper V2

AutoTyper types a plain-text draft into a field you choose. Use the **Mac app** to type into a desktop editor, or the **Chrome extension** to keep typing into one browser tab while you work elsewhere. You can install either one independently.

Both versions offer a five-second countdown and a speed range of **15–150 words per minute**. Choose a speed preset or adjust the slider. Turn on natural pauses for breaks between sentences, or enable mistakes to have AutoTyper occasionally type a nearby key, backspace, and correct it. The studio shows an estimated duration, progress, and controls to pause or stop a run.

| | Mac app | Chrome extension |
|---|---|---|
| Requirements | macOS 14 or later and Apple Command Line Tools to build | Chrome 118 or later |
| During a run | Keep the destination field focused | Keep the destination tab open and the computer awake |
| Stop shortcut | `Control + Option + Command + Esc` from any app | `Command + Shift + Y` on Mac or `Ctrl + Shift + Y` elsewhere, while Chrome is active |

## Install the Mac app

If you need the Apple Command Line Tools, run `xcode-select --install` and finish the installer. Then clone the repository and build the app in Terminal.

```sh
git clone https://github.com/primo8002/AutoTyper-V2.git
cd AutoTyper-V2
./scripts/build.sh
```

1. In Finder, open the generated `dist` folder. Drag `AutoTyper.app` into **Applications** and launch that copy.
2. For a first run, open a blank document in TextEdit. Paste a short sample into AutoTyper and click **Start typing**.
3. If the **Keyboard access** dialog appears, click **Request access** and enable AutoTyper in **System Settings → Privacy & Security → Accessibility**. Return to AutoTyper and click **Start typing** again.
4. During the countdown, click where the sample should appear in TextEdit. Keep that field focused until typing finishes. In apps where Return sends a message, a line break in your draft can send it.

## Install the Chrome extension

1. Clone or download and unzip this repository. Keep the extracted files where you want Chrome to load them from.
2. Open `chrome://extensions`, turn on **Developer mode**, click **Load unpacked**, and select the `browser-extension` folder. Pin AutoTyper to the toolbar for easy access.
3. Open a page with an editable field and click the insertion point with no text selected. Click the AutoTyper toolbar icon to open the studio.
4. Confirm the destination tab, paste your text, and click **Start in 5 seconds**. You can now switch tabs or apps. Leave the cursor in place in the destination editor.

The extension supports text inputs, text areas, and editable page regions. **Google Docs support is experimental.** Try a short sample in a blank document first. Password fields, read-only fields, Chrome settings pages, and editors inside cross-origin frames are unsupported. A run stops if the destination tab closes or navigates. After a run, check the destination's save indicator before closing the tab.

## Privacy and permissions

The Mac app uses Accessibility permission to send keystrokes. The Chrome extension uses `tabs` to list destinations, `debugger` to deliver input to the chosen tab, and `storage` to keep the draft and session status in browser memory. Chrome displays a debugging banner while the extension is attached. Closing Chrome clears the session draft.

AutoTyper requires no account and sends no drafts to an AutoTyper service. The app or website receiving the text handles it according to its own settings.

## Troubleshooting

**Accessibility is enabled, but Start still asks for access.** An existing permission entry can point to an older build or another copy. Quit AutoTyper, remove its old entry with **−** in Accessibility settings, then use **+** to add the copy in Applications. Enable it and reopen that same copy. The build script signs and verifies the bundle locally. Rebuilding with the default ad hoc signature can require fresh approval. Developers with a signing certificate can set `AUTOTYPER_SIGNING_IDENTITY` when running the build script to use the same identity across releases.

**Chrome shows the old studio after an update.** Click **Reload** on AutoTyper's card at `chrome://extensions`, close any open studio tabs, and launch the extension again from the destination. If its stop shortcut conflicts with another extension, change it at `chrome://extensions/shortcuts`.
