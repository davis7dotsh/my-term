# better-cmux

Native macOS prototype for a window-first terminal manager with:

- a persistent Arc-style sidebar of windows
- per-window tabs
- long-lived terminal sessions per tab
- Bun-wrapped `check`, `format`, and `dev` commands for the local workflow

## Requirements

- macOS
- Xcode command line tools / Swift 6 toolchain
- Bun

## Run

```bash
bun install
bun run dev
```

## Check

```bash
bun run format
bun run check
```

## Notes

- The current draft uses `SwiftTerm` for live terminal sessions so we can validate the product shape quickly.
- Window, tab, and profile metadata persist to `~/Library/Application Support/better-cmux/state.json`.
- Active profiles keep their windows, tabs, and working directories synced in the background and on app sleep/quit.
- Live shell process state is not restored on relaunch yet.
