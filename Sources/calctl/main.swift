import Foundation
import CalendarCore

// MARK: - Date Parser

public enum DateParser {
    private static let fullDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public static func parseDateTime(_ string: String) throws -> Date {
        if string.contains(":") {
            guard let date = fullDateTimeFormatter.date(from: string) else {
                throw CalendarError.invalidDate(string)
            }
            return date
        } else {
            guard let date = dateOnlyFormatter.date(from: string) else {
                throw CalendarError.invalidDate(string)
            }
            return date
        }
    }

    public static func parseDate(_ string: String) throws -> Date {
        guard let date = dateOnlyFormatter.date(from: string) else {
            throw CalendarError.invalidDate(string)
        }
        return date
    }
}

// MARK: - Lightweight Argument Parser

struct Args {
    let positional: [String]
    let options: [String: [String]]
    let flags: Set<String>

    init(argv: [String]) {
        var positional: [String] = []
        var options: [String: [String]] = [:]
        var flags = Set<String>()
        var idx = 0
        while idx < argv.count {
            let token = argv[idx]
            if token.hasPrefix("--") {
                let name = String(token.dropFirst(2))
                if idx + 1 >= argv.count || argv[idx + 1].hasPrefix("-") {
                    flags.insert(name)
                    idx += 1
                    continue
                }
                options[name, default: []].append(argv[idx + 1])
                idx += 2
            } else if token.hasPrefix("-") {
                for ch in token.dropFirst() { flags.insert(String(ch)) }
                idx += 1
            } else {
                positional.append(token)
                idx += 1
            }
        }
        self.positional = positional
        self.options = options
        self.flags = flags
    }

    func string(_ key: String) -> String? { options[key]?.first }
    func bool(_ key: String) -> Bool { flags.contains(key) }
}

// MARK: - Command Protocol

protocol Command {
    var name: String { get }
    func run(args: Args) async throws
}

// MARK: - Status Command

struct StatusCommand: Command {
    let name = "status"
    func run(args: Args) async throws {
        let status = CalendarEventsStore.authorizationStatus()
        switch status {
        case .fullAccess: print("authorized")
        case .notDetermined: print("notDetermined - run 'calctl authorize' to request access")
        case .denied, .restricted: print("denied - grant Terminal access in System Settings > Privacy & Security > Calendars")
        case .writeOnly: print("writeOnly - grant Full Access in System Settings > Privacy & Security > Calendars")
        }
    }
}

// MARK: - Authorize Command

struct AuthorizeCommand: Command {
    let name = "authorize"
    func run(args: Args) async throws {
        let store = CalendarEventsStore()
        try await store.requestAccess()
        print("authorized")
    }
}

// MARK: - List Command

struct ListCommand: Command {
    let name = "list"
    func run(args: Args) async throws {
        let store = CalendarEventsStore()
        try await store.requestAccess()
        let calendars = await store.calendars()
        if args.bool("json") {
            var info: [[String: Any]] = []
            for cal in calendars {
                info.append([
                    "id": cal.id,
                    "title": cal.title,
                    "sourceTitle": cal.sourceTitle,
                    "sourceType": cal.sourceType,
                ])
            }
            let data = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
            print(String(data: data, encoding: .utf8) ?? "[]")
        } else {
            for cal in calendars {
                print("\(cal.id)\t\(cal.title) [\(cal.sourceTitle)/\(cal.sourceType)]")
            }
            if calendars.isEmpty { print("(no calendars)") }
        }
    }
}

// MARK: - Today Command

struct TodayCommand: Command {
    let name = "today"
    func run(args: Args) async throws {
        let (start, end) = DateHelpers.todayRange()
        try await queryEvents(start: start, end: end, calendarName: args.string("calendar"), calendarID: args.string("calendar-id"), args: args, label: "Today")
    }
}

// MARK: - Tomorrow Command

struct TomorrowCommand: Command {
    let name = "tomorrow"
    func run(args: Args) async throws {
        let (start, end) = DateHelpers.tomorrowRange()
        try await queryEvents(start: start, end: end, calendarName: args.string("calendar"), calendarID: args.string("calendar-id"), args: args, label: "Tomorrow")
    }
}

// MARK: - Week Command

struct WeekCommand: Command {
    let name = "week"
    func run(args: Args) async throws {
        let (start, end) = DateHelpers.weekRange()
        try await queryEvents(start: start, end: end, calendarName: args.string("calendar"), calendarID: args.string("calendar-id"), args: args, label: "This Week")
    }
}

// MARK: - Date Command

struct DateCmd: Command {
    let name = "date"
    func run(args: Args) async throws {
        guard let dateStr = args.positional.first ?? args.string("date") else {
            print("Usage: calctl date <YYYY-MM-DD> [--calendar <name>] [--calendar-id <id>] [--json]")
            return
        }
        let start = try DateParser.parseDate(dateStr)
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: start))!
        try await queryEvents(start: start, end: end, calendarName: args.string("calendar"), calendarID: args.string("calendar-id"), args: args, label: dateStr)
    }
}

// MARK: - Add Command

struct AddCmd: Command {
    let name = "add"
    func run(args: Args) async throws {
        guard let title = args.string("title") else {
            print("Error: --title is required"); return
        }
        guard let startStr = args.string("start") else {
            print("Error: --start is required"); return
        }
        guard let endStr = args.string("end") else {
            print("Error: --end is required"); return
        }
        let draft = EventDraft(
            title: title,
            startDate: try DateParser.parseDateTime(startStr),
            endDate: try DateParser.parseDateTime(endStr),
            isAllDay: args.bool("all-day") ? true : nil,
            notes: args.string("notes"),
            location: args.string("location"),
            calendarName: args.string("calendar"),
            recurrenceRule: args.string("recurrence")
        )
        let store = CalendarEventsStore()
        try await store.requestAccess()
        let event = try await store.createEvent(draft)
        print("Created: \(event.title) (\(event.id))")
    }
}

// MARK: - Edit Command

struct EditCmd: Command {
    let name = "edit"
    func run(args: Args) async throws {
        guard let id = args.string("id") else {
            print("Error: --id is required"); return
        }
        let update = EventUpdate(
            title: args.string("title"),
            startDate: args.string("start").flatMap { try? DateParser.parseDateTime($0) },
            endDate: args.string("end").flatMap { try? DateParser.parseDateTime($0) },
            isAllDay: args.bool("all-day") ? true : nil,
            notes: args.string("notes"),
            location: args.string("location"),
            calendarName: args.string("calendar")
        )
        let store = CalendarEventsStore()
        try await store.requestAccess()
        let event = try await store.updateEvent(id: id, update: update)
        print("Updated: \(event.title) (\(event.id))")
    }
}

// MARK: - Delete Command

struct DeleteCmd: Command {
    let name = "delete"
    func run(args: Args) async throws {
        guard let id = args.string("id") else {
            print("Error: --id is required"); return
        }
        if !args.bool("force") {
            print("Delete event \(id)? [y/N] ", terminator: "")
            fflush(stdout)
            guard let response = readLine()?.trimmingCharacters(in: .whitespaces).lowercased(),
                  response == "y" || response == "yes" else {
                print("Aborted."); return
            }
        }
        let store = CalendarEventsStore()
        try await store.requestAccess()
        try await store.deleteEvent(id: id)
        print("Deleted: \(id)")
    }
}

// MARK: - Help Command

struct HelpCmd: Command {
    let name = "help"
    func run(args: Args) async throws {
        print("""
calctl - Apple Calendar CLI

USAGE
  calctl <command> [options]

COMMANDS
  status        Check authorization status
  authorize     Trigger calendar access prompt
  list          List all calendars
  today         Show today's events
  tomorrow      Show tomorrow's events
  week          Show this week's events
  date <date>   Show events for YYYY-MM-DD
  add           Create a new event
  edit          Update an existing event
  delete        Remove an event
  help          Show this message

GLOBAL OPTIONS
  --json                 JSON output
  --plain                Plain text output (default)
  --quiet                Count-only output
  --calendar <name>      Filter by calendar name
  --calendar-id <id>     Filter by calendar id (preferred when names duplicate)

EXAMPLES
  calctl list
  calctl today
  calctl date 2026-05-01 --calendar "Work"
  calctl add --title "Standup" --start "2026-04-11 09:00" --end "2026-04-11 09:30"
  calctl add --title "Weekly Standup" --start "2026-04-14 09:00" --end "2026-04-14 09:30" --recurrence "FREQ=WEEKLY;INTERVAL=1;BYDAY=MO"
  calctl delete --id <event-id> --force
""")
    }
}

// MARK: - Command Registry

let commands: [any Command] = [
    StatusCommand(),
    AuthorizeCommand(),
    ListCommand(),
    TodayCommand(),
    TomorrowCommand(),
    WeekCommand(),
    DateCmd(),
    AddCmd(),
    EditCmd(),
    DeleteCmd(),
    HelpCmd(),
]

// MARK: - Shared Query Helper

private func queryEvents(
    start: Date, end: Date,
    calendarName: String?, calendarID: String?, args: Args, label: String
) async throws {
    let store = CalendarEventsStore()
    try await store.requestAccess()
    var events = try await store.events(in: calendarName, startDate: start, endDate: end)
    if let calendarID, !calendarID.isEmpty {
        events = events.filter { $0.calendarID == calendarID }
    }
    let formatter = OutputFormatter(mode: args.bool("json") ? .json : .plain)
    if let output = formatter.formatEvents(events, dateLabel: label) { print(output) }
}

// MARK: - Entry Point

let argv = Array(CommandLine.arguments.dropFirst())

func showHelp() {
    print("""
calctl - Apple Calendar CLI

USAGE
  calctl <command> [options]

COMMANDS
  status        Check authorization status
  authorize     Trigger calendar access prompt
  list          List all calendars
  today         Show today's events
  tomorrow      Show tomorrow's events
  week          Show this week's events
  date <date>   Show events for YYYY-MM-DD
  add           Create a new event
  edit          Update an existing event
  delete        Remove an event
  help          Show detailed help

Run 'calctl help' for full usage.
""")
}

guard let commandName = argv.first else {
    showHelp()
    exit(0)
}

let subcommandArgs = Array(argv.dropFirst())

if commandName == "help" || commandName == "--help" || commandName == "-h" {
    showHelp()
    exit(0)
}

guard let command = commands.first(where: { $0.name == commandName }) else {
    print("Unknown command: \(commandName)")
    print("Run 'calctl help' for usage.")
    exit(1)
}

do {
    try await command.run(args: Args(argv: subcommandArgs))
} catch {
    print("Error: \(error)")
    exit(1)
}
