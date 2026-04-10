# calctl

Native macOS CLI for Apple Calendar via EventKit.

> **Inspiration & props:** This project is directly inspired by [steipete/remindctl](https://github.com/steipete/remindctl) — a great native CLI for Apple Reminders. `calctl` follows the same spirit for Apple Calendar: fast, scriptable, and no AppleScript/osascript.

## Build

```bash
git clone <repo-url> calctl
cd calctl
swift build
```

**Binary:** `.build/arm64-apple-macosx/debug/calctl`

To install globally:
```bash
cp .build/arm64-apple-macosx/debug/calctl /usr/local/bin/calctl
chmod +x /usr/local/bin/calctl
```

> Requires macOS 14+ (Sonoma) and Swift 6.0+

## Permission Setup

Apple Calendar access requires explicit user authorization.

1. On first run the tool prompts you automatically.
2. Accept the system dialog.
3. If access is denied, open: **System Settings → Privacy & Security → Calendars → Terminal → Allow**

If running over SSH, run `calctl status` on the physical Mac once to trigger the prompt.

## Command Cheatsheet

| Command | Description |
|---------|-------------|
| `calctl status` | Check calendar access status |
| `calctl authorize` | Trigger the permission prompt |
| `calctl list` | List all calendars |
| `calctl today` | Show today events |
| `calctl tomorrow` | Show tomorrow events |
| `calctl week` | Show this week events |
| `calctl date YYYY-MM-DD` | Show events for a date |
| `calctl add --title "..." --start "..." --end "..."` | Create an event |
| `calctl edit --id <id> ...` | Edit an event |
| `calctl delete --id <id>` | Delete an event |

## Quick Examples

```bash
# List calendars
calctl list

# Check auth status
calctl status

# Today events
calctl today

# Specific date
calctl date 2026-05-01 --calendar "Work"

# Create an event
calctl add \
  --title "Team Standup" \
  --start "2026-04-11 09:00" \
  --end "2026-04-11 09:30"

# Delete (prompts for confirmation)
calctl delete --id <event-id>

# Delete without prompting
calctl delete --id <event-id> --force
```

## Smoke Test

```bash
./scripts/smoke.sh
```

Builds, runs `--help`, `status`, `list`, and `today`. Non-destructive. Exit 0 = pass.

## Tech Stack

- Swift 6.0+ / macOS 14+
- EventKit (native, no AppleScript)
- Swift Package Manager

## Acknowledgements

- Huge credit to **[Peter Steinberger (@steipete)](https://github.com/steipete)** for [remindctl](https://github.com/steipete/remindctl).
- `calctl` exists because remindctl proved how effective native EventKit-based tooling can be for Apple productivity workflows.

---

See [SPEC.md](./SPEC.md) for full CLI grammar and [BACKLOG.md](./BACKLOG.md) for feature status.
