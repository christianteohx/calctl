import Foundation
import CalendarCore

// MARK: - Output Mode

public enum OutputMode: String {
    case json
    case plain
    case quiet
}

// MARK: - JSON Output

public struct JSONOutput {
    public let encoder: JSONEncoder

    public init(pretty: Bool = true) {
        encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
    }

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
}

// MARK: - Output Formatter

public struct OutputFormatter {
    private let jsonOutput: JSONOutput
    private let mode: OutputMode

    public init(mode: OutputMode) {
        self.mode = mode
        self.jsonOutput = JSONOutput(pretty: mode == .json)
    }

    // MARK: - Status

    public struct StatusOutput: Codable {
        public let authorized: Bool
        public let status: String
        public let defaultCalendar: String?

        public init(authorized: Bool, status: CalendarAuthorizationStatus, defaultCalendar: String?) {
            self.authorized = authorized
            self.status = String(describing: status)
            self.defaultCalendar = defaultCalendar
        }
    }

    public func formatStatus(authorized: Bool, status: CalendarAuthorizationStatus, defaultCalendar: String?) -> String? {
        switch mode {
        case .json:
            let out = StatusOutput(authorized: authorized, status: status, defaultCalendar: defaultCalendar)
            return formatJSON(out)
        case .plain:
            var lines = [String]()
            lines.append("Authorization: \(authorized ? "granted" : "denied")")
            lines.append("Status: \(status)")
            if let cal = defaultCalendar {
                lines.append("Default Calendar: \(cal)")
            }
            return lines.joined(separator: "\n")
        case .quiet:
            return authorized ? "1" : "0"
        }
    }

    // MARK: - Calendar List

    public struct CalendarListOutput: Codable {
        public let calendars: [CalendarInfo]

        public struct CalendarInfo: Codable {
            public let id: String
            public let title: String
            public let sourceTitle: String
            public let sourceType: String
            public let isDefault: Bool

            public init(id: String, title: String, sourceTitle: String, sourceType: String, isDefault: Bool) {
                self.id = id
                self.title = title
                self.sourceTitle = sourceTitle
                self.sourceType = sourceType
                self.isDefault = isDefault
            }
        }
    }

    public func formatCalendarList(_ calendars: [CalendarList], defaultName: String?) -> String? {
        switch mode {
        case .json:
            let info = calendars.map {
                CalendarListOutput.CalendarInfo(
                    id: $0.id,
                    title: $0.title,
                    sourceTitle: $0.sourceTitle,
                    sourceType: $0.sourceType,
                    isDefault: $0.title == defaultName
                )
            }
            return formatJSON(CalendarListOutput(calendars: info))
        case .plain:
            var lines = [String]()
            for cal in calendars {
                let marker = cal.title == defaultName ? " (default)" : ""
                lines.append("\(cal.id)\t\(cal.title)\(marker)")
            }
            return lines.joined(separator: "\n")
        case .quiet:
            return "\(calendars.count)"
        }
    }

    // MARK: - Events

    public struct AttendeeOutput: Codable {
        public let name: String?
        public let email: String?
        public let status: String
        public let isCurrentUser: Bool

        public init(attendee: Attendee) {
            self.name = attendee.name
            self.email = attendee.email
            self.status = attendee.status
            self.isCurrentUser = attendee.isCurrentUser
        }
    }

    public struct EventOutput: Codable {
        public let id: String
        public let title: String
        public let startDate: String
        public let endDate: String
        public let isAllDay: Bool
        public let notes: String?
        public let location: String?
        public let calendarName: String
        public let sourceTitle: String
        public let sourceType: String
        public let attendees: [AttendeeOutput]?

        public init(event: CalendarEvent, includeAttendees: Bool = false) {
            self.id = event.id
            self.title = event.title
            self.startDate = OutputFormatter.dateFormatter.string(from: event.startDate)
            self.endDate = OutputFormatter.dateFormatter.string(from: event.endDate)
            self.isAllDay = event.isAllDay
            self.notes = event.notes
            self.location = event.location
            self.calendarName = event.calendarName
            self.sourceTitle = event.calendarSourceTitle
            self.sourceType = event.calendarSourceType
            self.attendees = includeAttendees ? event.attendees.map { AttendeeOutput(attendee: $0) } : nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    public func formatEvents(_ events: [CalendarEvent], dateLabel: String? = nil, showAttendees: Bool = false) -> String? {
        switch mode {
        case .json:
            let output = events.map { EventOutput(event: $0, includeAttendees: showAttendees) }
            return formatJSON(output)
        case .plain:
            var lines = [String]()
            if let label = dateLabel {
                lines.append("=== \(label) ===")
            }
            if events.isEmpty {
                lines.append("(no events)")
            } else {
                for event in events {
                    let time = event.isAllDay
                        ? "All day"
                        : "\(Self.timeFormatter.string(from: event.startDate)) - \(Self.timeFormatter.string(from: event.endDate))"
                    lines.append("[\(time)] \(event.title) (\(event.calendarName) · \(event.calendarSourceTitle)/\(event.calendarSourceType))")
                    if let loc = event.location, !loc.isEmpty {
                        lines.append("  Location: \(loc)")
                    }
                    if showAttendees && !event.attendees.isEmpty {
                        lines.append("  Attendees:")
                        for attendee in event.attendees {
                            let currentUserMarker = attendee.isCurrentUser ? " (you)" : ""
                            let name = attendee.displayName
                            let email = attendee.email.map { " <\($0)>" } ?? ""
                            lines.append("    - \(name)\(email) [\(attendee.status)]\(currentUserMarker)")
                        }
                    }
                }
            }
            return lines.joined(separator: "\n")
        case .quiet:
            return "\(events.count)"
        }
    }

    // MARK: - Single Event

    public func formatEvent(_ event: CalendarEvent) -> String? {
        switch mode {
        case .json:
            let output = EventOutput(event: event)
            return formatJSON(output)
        case .plain:
            var lines = [String]()
            lines.append("Title: \(event.title)")
            lines.append("Start: \(Self.dateFormatter.string(from: event.startDate))")
            lines.append("End: \(Self.dateFormatter.string(from: event.endDate))")
            lines.append("Calendar: \(event.calendarName)")
            lines.append("Account: \(event.calendarSourceTitle) (\(event.calendarSourceType))")
            if event.isAllDay {
                lines.append("All day: yes")
            }
            if let notes = event.notes, !notes.isEmpty {
                lines.append("Notes: \(notes)")
            }
            if let location = event.location, !location.isEmpty {
                lines.append("Location: \(location)")
            }
            return lines.joined(separator: "\n")
        case .quiet:
            return event.id
        }
    }

    // MARK: - Helpers

    private func formatJSON<T: Encodable>(_ value: T) -> String? {
        guard let data = try? jsonOutput.encode(value),
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }
}

// MARK: - Date Helpers

public struct DateHelpers {
    public static let calendar = Calendar.current

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init() {}

    public static func todayRange() -> (start: Date, end: Date) {
        let now = Date()
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }

    public static func tomorrowRange() -> (start: Date, end: Date) {
        let now = Date()
        let start = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: start)!
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrowStart)!
        return (tomorrowStart, tomorrowEnd)
    }

    public static func weekRange() -> (start: Date, end: Date) {
        let now = Date()
        let start = calendar.startOfDay(for: now)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        return (weekStart, weekEnd)
    }

    public static func parseDate(_ string: String) -> Date? {
        dayFormatter.date(from: string)
    }

    public static func formatDate(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    public static func dayLabel(start: Date, end: Date) -> String {
        let cal = calendar
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart)!

        if start == todayStart && end == todayEnd {
            return "Today"
        }

        let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart)!
        let tomorrowEnd = cal.date(byAdding: .day, value: 1, to: tomorrowStart)!
        if start == tomorrowStart && end == tomorrowEnd {
            return "Tomorrow"
        }

        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: todayStart))!
        if start == weekStart && end == cal.date(byAdding: .day, value: 7, to: weekStart) {
            return "This Week"
        }

        return formatDate(start)
    }
}
