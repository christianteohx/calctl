---
name: calctl
description: Native macOS Apple Calendar CLI (EventKit). List calendars/events and add/edit/delete events from terminal. Inspired by steipete/remindctl.
homepage: https://github.com/christianteohx/calctl
user-invocable: true
metadata:
  {
    "openclaw":
      {
        "emoji": "🗓️",
        "requires": { "bins": ["swift"] }
      }
  }
---

# calctl

`calctl` is a native Apple Calendar command-line tool for macOS, built with Swift + EventKit.

## Typical usage

```bash
calctl status
calctl list
calctl today
calctl date 2026-04-17
calctl add --title "LANY: Soft World Tour" --start "2026-04-17 19:30" --end "2026-04-17 22:30"
```

## Notes

- macOS only
- Requires Calendar permission for Terminal
- No AppleScript/osascript

## Inspiration

This project was inspired by [steipete/remindctl](https://github.com/steipete/remindctl).
