import Foundation

public struct Attendee: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String?
    public let email: String?
    public let status: String
    public let isCurrentUser: Bool

    public init(id: String, name: String?, email: String?, status: String, isCurrentUser: Bool) {
        self.id = id
        self.name = name
        self.email = email
        self.status = status
        self.isCurrentUser = isCurrentUser
    }

    public var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if let email = email, !email.isEmpty {
            return email
        }
        return "Unknown"
    }
}

public struct CalendarEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let notes: String?
    public let location: String?
    public let calendarID: String
    public let calendarName: String
    public let calendarSourceTitle: String
    public let calendarSourceType: String
    public let recurrenceRule: String?
    public let attendees: [Attendee]

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        notes: String?,
        location: String?,
        calendarID: String,
        calendarName: String,
        calendarSourceTitle: String,
        calendarSourceType: String,
        recurrenceRule: String?,
        attendees: [Attendee] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.notes = notes
        self.location = location
        self.calendarID = calendarID
        self.calendarName = calendarName
        self.calendarSourceTitle = calendarSourceTitle
        self.calendarSourceType = calendarSourceType
        self.recurrenceRule = recurrenceRule
        self.attendees = attendees
    }
}

public struct CalendarList: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let sourceTitle: String
    public let sourceType: String

    public init(id: String, title: String, sourceTitle: String, sourceType: String) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.sourceType = sourceType
    }
}

public struct EventDraft: Sendable {
    public let title: String?
    public let startDate: Date?
    public let endDate: Date?
    public let isAllDay: Bool?
    public let notes: String?
    public let location: String?
    public let calendarName: String?
    public let recurrenceRule: String?

    public init(
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool? = nil,
        notes: String? = nil,
        location: String? = nil,
        calendarName: String? = nil,
        recurrenceRule: String? = nil
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.notes = notes
        self.location = location
        self.calendarName = calendarName
        self.recurrenceRule = recurrenceRule
    }
}

public struct EventUpdate: Sendable {
    public let title: String?
    public let startDate: Date?
    public let endDate: Date?
    public let isAllDay: Bool?
    public let notes: String?
    public let location: String?
    public let calendarName: String?
    public let recurrenceRule: String?

    public init(
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool? = nil,
        notes: String? = nil,
        location: String? = nil,
        calendarName: String? = nil,
        recurrenceRule: String? = nil
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.notes = notes
        self.location = location
        self.calendarName = calendarName
        self.recurrenceRule = recurrenceRule
    }
}
