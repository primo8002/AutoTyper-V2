# AutoTyper 0.3 design

The desktop app and browser extension share a workspace layout: a charcoal navigation rail, warm paper background, white draft editor, settings inspector, and fixed run bar. Burnt orange identifies primary actions and the app icon. Large speed values and three working presets make the main setting easy to scan.

The layout replaces the previous stack of dark cards. The editor expands into available space; run controls remain visible. Browser layouts collapse into one column on narrow screens. Focus outlines, labeled controls, disabled states, and reduced-motion handling remain available.

## Research

- [Linear: A calmer interface for a product in motion](https://linear.app/now/behind-the-latest-design-refresh): consistent headers, quieter navigation, and clearer hierarchy informed the workspace structure.
- [Linear: redesigned UI](https://linear.app/changelog/2024-03-20-new-linear-ui): balance and density informed the compact settings inspector.
- [Raycast: the next generation](https://www.raycast.com/new): a focused desktop utility informed compact controls and persistent actions.
- [Apple: app icons](https://developer.apple.com/design/human-interface-guidelines/app-icons/): a simple, recognizable silhouette informed the original A-and-cursor mark.

These are design references; AutoTyper uses original layouts and artwork.

## Icon assets

`assets/AutoTyper.svg` is the vector mark. `scripts/make-icons.swift` produces PNGs at exact pixel sizes using AppKit, without dependencies. `assets/AutoTyper.icns` is bundled by the build script; the Chrome manifest references the 16, 32, 48 and 128 pixel icons.

To regenerate:

```sh
swift scripts/make-icons.swift "$PWD"
iconutil -c icns assets/AutoTyper.iconset -o assets/AutoTyper.icns
./scripts/build.sh
```

## Showing the latest version

The installed app must be quit and reopened after replacing its bundle. A running process retains its old interface. The new sidebar shows **v0.3**.

For Chrome, reload AutoTyper at `chrome://extensions`, close old studio tabs, then open the extension again from the destination tab. If another unpacked copy is installed, remove that duplicate and load this repository's `browser-extension` directory. Confirm version **0.3.0** and the orange icon on the extension card.

## Verification

- Native app compiled and rendered in an isolated AppKit hosting view.
- Actual extension loaded in an isolated Chromium profile; desktop and 390px layouts inspected.
- Speed preset, character count, frequency toggle, and narrow-screen overflow checked.
- Installed executable and icon compared against the new build.
