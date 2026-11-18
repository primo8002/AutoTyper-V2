# AutoTyper V2

A native macOS app that types supplied plain text into the currently focused text field.

## Run it

On macOS 14 or newer with the Apple command line tools installed:

```sh
./scripts/build.sh
open dist/AutoTyper.app
```

The first Start attempt asks macOS for Accessibility access. Enable **AutoTyper** in **System Settings → Privacy & Security → Accessibility**, then restart the app if macOS requests it. Paste text, set the pace, press **Start typing**, and click the destination text field during the visible five-second countdown. Press **Control–Option–Command–Escape** to stop from anywhere. The text and settings stay local to the app and are not sent to a server.

## What is implemented

- 15–150 words-per-minute control with changing per-character timing and short bursts.
- Optional nearby-key mistakes, Backspace corrections, and a frequency slider. Corrections may happen immediately or after the next one or two characters. A new random sequence is generated for every run.
- Optional pauses after punctuation and paragraphs.
- Five-second warning and target-switch window before typing begins.
- Progress, approximate duration, pause/resume, stop, and a global emergency-stop shortcut.
- Native macOS application bundle and a dark, keyboard-friendly interface.

The app types plain text into the active field. It does not guarantee that a target app will accept every simulated event, preserve exact rich formatting, or interpret Return as a line break; some chat fields send on Return. Test with a short sample in the target app first. Typing patterns vary, but no app can guarantee that generated activity is indistinguishable from human input.

## Product plan

1. **V2 foundation (built):** local desktop app, straightforward editor, visible controls, five-second countdown, variable speed, corrections, progress, pause and emergency stop.
2. **Reliability pass:** detect destination focus changes and secure fields, add a target-specific compatibility matrix for Google Docs, Word, Slides, and ordinary forms, and build a manual smoke-test suite for Unicode and newlines.
3. **Editing workflow:** saved drafts, multiple text blocks, per-block destinations, and formatted text where the target app exposes a dependable editing API.
4. **Optional advanced controls:** saved pacing presets, break frequency and duration, correction timing, live speed changes, completion notifications, and target-aware estimated finish times.



## Sources

- [Duey AI Auto Typer 3.0 announcement](https://www.duey.ai/post/duey-auto-typer-3-0-multi-block-typing-emergency-stop-adaptive-corrections)
- [Duey AI Chrome Web Store feature listing](https://chromewebstore.google.com/detail/auto-typer-typing-simulat/ilamopeagajnekeaogejpdmffneankjf)
- [Duey AI product overview](https://www.duey.ai/help/what-is-duey)
