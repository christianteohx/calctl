# calctl

Native macOS Calendar CLI built with EventKit. No AppleScript, no osascript.

## Install

```bash
brew install christianteohx/tap/calctl
```

Or download the latest binary from [Releases](https://github.com/christianteohx/calctl/releases).

## Commands

```
calctl status                    check calendar access status
calctl authorize                 trigger permission prompt
calctl list                      list all calendars (with id, title, source)
calctl today                     show today's events
calctl tomorrow                  show tomorrow's events
calctl week                      show this week's events
calctl date YYYY-MM-DD           show events for a specific date
calctl add --title ... --start ... --end ...    create an event
calctl edit --id <id> ...        edit an event
calctl delete --id <id>          delete an event
```

## Recurring Events

```bash
# Weekly Monday standup
calctl add --title "Standup" --start "2026-04-14 09:00" --end "2026-04-14 09:30" \
  --recurrence "FREQ=WEEKLY;INTERVAL=1;BYDAY=MO"

# Daily reminder
calctl add --title "Reminder" --start "2026-04-15 08:00" --end "2026-04-15 08:05" \
  --recurrence "FREQ=DAILY"

# Monthly on 1st
calctl add --title "Report" --start "2026-05-01 10:00" --end "2026-05-01 11:00" \
  --recurrence "FREQ=MONTHLY;BYMONTHDAY=1"
```

## Single Occurrence Edit/Delete

For recurring events, use `--this-only` to edit or delete only the selected occurrence:

```bash
calctl edit --id <event-id> --title "Rescheduled" --this-only
calctl delete --id <event-id> --this-only
```

Without `--this-only`, changes apply to this and all future occurrences.

## Options

```
--json                 JSON output
--plain                Plain text output (default)
--calendar <name>      Filter by calendar name
--calendar-id <id>     Filter by calendar id
--attendees            Show attendee details for event queries (today/tomorrow/week/date)
```

## Attendees

View attendee details for events using the `--attendees` flag with `today`, `tomorrow`, `week`, or `date` commands:

```bash
# Show today's events with attendees
calctl today --attendees

# Show this week's events with attendees
calctl week --attendees

# JSON output with attendees
calctl today --attendees --json

# Specific date with attendees
calctl date 2026-05-01 --attendees
```

Each attendee shows name/email and participation status (accepted, pending, declined, tentative).

## Build from Source

Requires macOS 14+ and Swift 6.0+.

```bash
git clone https://github.com/christianteohx/calctl
cd calctl
swift build -c release
.build/release/calctl <command>
```

## License

MIT
