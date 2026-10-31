# Clip History

A small, open-source clipboard history for macOS. It lives in the menu bar, keeps everything you
copy and every screenshot you take, sorts them into categories, and brings them back with
**⇧⌘V**: type to search, pick with ↑ ↓, press ↩ to paste.

Native Swift (SwiftUI + AppKit), no dependencies, nothing leaves your Mac.

## Features

- **Records** text, links, images, files copied in Finder, and screenshots: every screenshot saved
  to a file (found through Spotlight, wherever macOS saves it) and screenshots taken to the
  clipboard (⌃⇧⌘3/4).
- **Popup on ⇧⌘V** (or a shortcut you choose), newest first, with category tabs: All, Text, Links,
  Images, Files, Screenshots.
- **Search** that ignores case and accents (Turkish included: "istanbul" finds "İSTANBUL").
  Fuzzy mode, the default, also finds typos ("raed" or "red" finds "read") and ranks results:
  whole word, word start, inside a word, then similar words. Matches are highlighted in the
  preview, with a list of what was found.
- **Paste** into the app you were in with ↩, or only copy with ⌘↩.
- **Preview** of text, links, images and screenshots, with where and when each item was copied.
- **Limits**: keep the newest N items, the newest items up to N MB, or everything; optionally
  remove items older than N days.
- **Privacy**: items that password managers mark as concealed or transient are never recorded.
- **English and Turkish** interface, switchable in the settings.
- Opens at login; pause recording from the menu bar.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later (Swift 6 toolchain) to build

## Install

There is no signed download yet, so build it from source:

```bash
git clone https://github.com/haldunerbay/macclipboard.git
cd macclipboard
make install
```

`make install` builds a release version, signs it, copies **Clip History.app** to
`/Applications` and starts it. It signs with your Apple Development certificate when you have one,
otherwise ad hoc; with an ad hoc signature macOS asks for the Accessibility permission again after
every rebuild. Other targets: `make app` (build only, into `build/`), `make run`, `make test`.

## Using it

| Key          | Action                                                                  |
| ------------ | ----------------------------------------------------------------------- |
| ⇧⌘V          | open or close the history                                               |
| type         | search every item                                                        |
| ↑ ↓          | move through the list (⌘↑ ⌘↓ first and last, Page Up and Down by 8)     |
| ↩            | paste the selected item into the app you were in                        |
| ⌘↩           | only copy it to the clipboard                                           |
| ⇥ ⇧⇥, ⌘1…⌘6  | switch category                                                          |
| ⌘⌫           | delete the selected item from the history                               |
| esc          | clear the search, then close                                            |
| ⌘, or ⚙      | settings                                                                 |

Double-click pastes too. `open cliphistory://show` opens the popup from scripts (Shortcuts,
Raycast), `open cliphistory://settings` the settings.

While you search, the All tab leaves screenshots out so the list stays fast; the Screenshots tab
searches them by file name.

## Settings

- **General**: language (English, Türkçe), open at login.
- **Search**: full text, or fuzzy (forgives typos).
- **History**: keep the newest N items (500 by default), the newest items up to N MB (texts, file
  paths and copied images; screenshot files do not count), or everything. Over the limit, the
  oldest items are removed when a new one arrives. Optionally remove items N days after they were
  last copied or pasted; that is checked at launch, when the history opens, on every copy and
  every 10 minutes.
- **Shortcut**: click it and press new keys (it needs ⌘, ⌥ or ⌃; esc cancels, Reset goes back to
  ⇧⌘V).

## Permissions

- **Accessibility**, asked on first launch: needed to press ⌘V for you. Without it, ↩ copies the
  item and you paste with ⌘V yourself.
- **Desktop, Documents, Downloads**: asked the first time a screenshot from there is shown.
- macOS may ask once whether Clip History may read what other apps copy: choose **Allow**.

⇧⌘V is "Paste and Match Style" in some apps; while Clip History runs, the shortcut opens the
history instead. Pick another one in the settings if you need that.

## Privacy

The history stays on your Mac, in `~/Library/Application Support/ClipHistory/` (a JSON file and
the copied images). The app makes no network requests. Screenshot files stay where macOS saved
them; deleting a screenshot removes it from the history. **Clear History…** in the menu bar menu
empties it.

## Development

```text
Sources/ClipCore/      model, search (fuzzy matching, ranking, highlights), history store
Sources/ClipHistory/   the app: pasteboard and screenshot watchers, popup, settings, hotkey, paste
Tests/                 unit tests for both (Swift Testing)
Support/Info.plist     the app bundle's Info.plist
Makefile               build, bundle, sign, install
```

```bash
make test        # or: swift test
swift build      # debug build of the executable
```

Issues and pull requests are welcome. Please add a test with a change and keep `make test` green.

## License

[MIT](LICENSE)
