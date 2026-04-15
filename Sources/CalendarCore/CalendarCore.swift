import EventKit
import Foundation

public enum CalendarAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case writeOnly
    case fullAccess

    public init(eventKitStatus: EKAuthorizationStatus) {
        switch eventKitStatus {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .writeOnly:
            self = .writeOnly
        case .fullAccess:
            self = .fullAccess
        @unknown default:
            self = .denied
        }
    }
}

public actor CalendarEventsStore {
    private let eventStore = EKEventStore()
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func requestAccess() async throws {
        let status = Self.authorizationStatus()
        switch status {
        case .notDetermined:
            let updated = try await requestAuthorization()
            if updated != .fullAccess {
                throw CalendarError.accessDenied
            }
        case .denied, .restricted:
            throw CalendarError.accessDenied
        case .writeOnly:
            throw CalendarError.writeOnlyAccess
        case .fullAccess:
            break
        }
    }

    public static func authorizationStatus() -> CalendarAuthorizationStatus {
        CalendarAuthorizationStatus(eventKitStatus: EKEventStore.authorizationStatus(for: .event))
    }

    public func requestAuthorization() async throws -> CalendarAuthorizationStatus {
        let status = Self.authorizationStatus()
        switch status {
        case .notDetermined:
            let granted = try await requestFullAccess()
            return granted ? .fullAccess : .denied
        default:
            return status
        }
    }

    public func calendars() -> [CalendarList] {
        eventStore.calendars(for: .event).map { calendar in
            CalendarList(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                sourceTitle: calendar.source.title,
                sourceType: sourceTypeString(calendar.source.sourceType)
            )
        }
    }

    public func defaultCalendarName() -> String? {
        eventStore.defaultCalendarForNewEvents?.title
    }

    public func events(in calendarName: String?, startDate: Date, endDate: Date) async throws -> [CalendarEvent] {
        let calendars: [EKCalendar]
        if let calendarName {
            calendars = eventStore.calendars(for: .event).filter { $0.title == calendarName }
            if calendars.isEmpty {
                throw CalendarError.calendarNotFound(calendarName)
            }
        } else {
            calendars = eventStore.calendars(for: .event)
        }

        return await fetchEvents(in: calendars, startDate: startDate, endDate: endDate)
    }

    public func createEvent(_ draft: EventDraft) async throws -> CalendarEvent {
        guard let title = draft.title, !title.isEmpty else {
            throw CalendarError.operationFailed("Event title is required")
        }
        guard let startDate = draft.startDate else {
            throw CalendarError.operationFailed("Start date is required")
        }
        guard let endDate = draft.endDate else {
            throw CalendarError.operationFailed("End date is required")
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = draft.notes
        event.location = draft.location
        event.isAllDay = draft.isAllDay ?? false

        if let calendarName = draft.calendarName {
            let calendar = try calendar(named: calendarName)
            event.calendar = calendar
        } else if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
            event.calendar = defaultCalendar
        }

        if let rrule = draft.recurrenceRule {
            event.recurrenceRules = [try parseRecurrenceRule(rrule, startDate: startDate)]
        }

        try eventStore.save(event, span: .futureEvents, commit: true)
        return eventToCalendarEvent(event)
    }

    public func updateEvent(id: String, update: EventUpdate, span: EKSpan = .futureEvents) async throws -> CalendarEvent {
        let event = try event(withID: id)

        if let title = update.title {
            event.title = title
        }
        if let startDate = update.startDate {
            event.startDate = startDate
        }
        if let endDate = update.endDate {
            event.endDate = endDate
        }
        if let isAllDay = update.isAllDay {
            event.isAllDay = isAllDay
        }
        if let notes = update.notes {
            event.notes = notes
        }
        if let location = update.location {
            event.location = location
        }
        if let calendarName = update.calendarName {
            event.calendar = try calendar(named: calendarName)
        }

        try eventStore.save(event, span: span, commit: true)
        return eventToCalendarEvent(event)
    }

    public func deleteEvent(id: String, span: EKSpan = .futureEvents) async throws {
        let event = try event(withID: id)
        try eventStore.remove(event, span: span, commit: true)
    }

    private func requestFullAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: granted)
            }
        }
    }

    private func fetchEvents(in calendars: [EKCalendar], startDate: Date, endDate: Date) async -> [CalendarEvent] {
        struct EventData: Sendable {
            let id: String
            let title: String
            let startDate: Date
            let endDate: Date
            let isAllDay: Bool
            let notes: String?
            let location: String?
            let calendarID: String
            let calendarName: String
            let calendarSourceTitle: String
            let calendarSourceType: String
            let recurrenceRule: String?
            let attendees: [Attendee]
        }

        let eventData = await withCheckedContinuation { (continuation: CheckedContinuation<[EventData], Never>) in
            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
            let events = eventStore.events(matching: predicate)

            let data = events.map { event in
                let attendees = extractAttendees(from: event)
                return EventData(
                    id: event.eventIdentifier,
                    title: event.title ?? "",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    notes: event.notes,
                    location: event.location,
                    calendarID: event.calendar.calendarIdentifier,
                    calendarName: event.calendar.title,
                    calendarSourceTitle: event.calendar.source.title,
                    calendarSourceType: sourceTypeString(event.calendar.source.sourceType),
                    recurrenceRule: nil,
                    attendees: attendees
                )
            }
            continuation.resume(returning: data)
        }

        return eventData.map { data in
            CalendarEvent(
                id: data.id,
                title: data.title,
                startDate: data.startDate,
                endDate: data.endDate,
                isAllDay: data.isAllDay,
                notes: data.notes,
                location: data.location,
                calendarID: data.calendarID,
                calendarName: data.calendarName,
                calendarSourceTitle: data.calendarSourceTitle,
                calendarSourceType: data.calendarSourceType,
                recurrenceRule: data.recurrenceRule,
                attendees: data.attendees
            )
        }
    }

    private func extractAttendees(from event: EKEvent) -> [Attendee] {
        guard let participants = event.attendees else { return [] }
        return participants.compactMap { participant in
            let statusString: String
            switch participant.participantStatus {
            case .pending: statusString = "pending"
            case .accepted: statusString = "accepted"
            case .declined: statusString = "declined"
            case .tentative: statusString = "tentative"
            case .delegated: statusString = "delegated"
            case .completed: statusString = "completed"
            case .inProcess: statusString = "inProcess"
            case .unknown: statusString = "unknown"
            @unknown default: statusString = "unknown"
            }
            return Attendee(
                id: participant.url.absoluteString,
                name: participant.name,
                email: extractEmail(from: participant),
                status: statusString,
                isCurrentUser: participant.isCurrentUser
            )
        }
    }

    private func extractEmail(from participant: EKParticipant) -> String? {
        // EKParticipant URL is typically mailto:email@example.com
        let urlString = participant.url.absoluteString
        if urlString.hasPrefix("mailto:") {
            return String(urlString.dropFirst(7))
        }
        return nil
    }

    private func event(withID id: String) throws -> EKEvent {
        guard let event = eventStore.event(withIdentifier: id) else {
            throw CalendarError.eventNotFound(id)
        }
        return event
    }

    private func calendar(named name: String) throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event).filter { $0.title == name }
        guard let calendar = calendars.first else {
            throw CalendarError.calendarNotFound(name)
        }
        return calendar
    }

    private func eventToCalendarEvent(_ event: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: event.eventIdentifier,
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            notes: event.notes,
            location: event.location,
            calendarID: event.calendar.calendarIdentifier,
            calendarName: event.calendar.title,
            calendarSourceTitle: event.calendar.source.title,
            calendarSourceType: sourceTypeString(event.calendar.source.sourceType),
            recurrenceRule: nil,
            attendees: extractAttendees(from: event)
        )
    }


    private func sourceTypeString(_ type: EKSourceType) -> String {
        switch type {
        case .local: return "local"
        case .exchange: return "exchange"
        case .calDAV: return "caldav"
        case .mobileMe: return "mobileme"
        case .subscribed: return "subscribed"
        case .birthdays: return "birthdays"
        @unknown default: return "unknown"
        }
    }

    private func parseRecurrenceRule(_ rrule: String, startDate: Date) throws -> EKRecurrenceRule {
        var frequency: EKRecurrenceFrequency = .daily
        var interval = 1
        var daysOfTheWeek: [EKRecurrenceDayOfWeek] = []
        var daysOfTheMonth: [NSNumber] = []
        var occurrenceCount: Int? = nil
        var endDate: Date? = nil

        let parts = rrule.split(separator: ";").map { String($0) }
        for part in parts {
            let keyValue = part.split(separator: "=", maxSplits: 1).map { String($0) }
            guard keyValue.count == 2 else { continue }
            let key = keyValue[0], value = keyValue[1]

            switch key {
            case "FREQ":
                switch value {
                case "DAILY": frequency = .daily
                case "WEEKLY": frequency = .weekly
                case "MONTHLY": frequency = .monthly
                case "YEARLY": frequency = .yearly
                default: frequency = .daily
                }
            case "INTERVAL":
                interval = Int(value) ?? 1
            case "BYDAY":
                let dayMap: [String: EKWeekday] = [
                    "MO": .monday, "TU": .tuesday, "WE": .wednesday,
                    "TH": .thursday, "FR": .friday, "SA": .saturday, "SU": .sunday
                ]
                let days = value.split(separator: ",").map { String($0) }
                for day in days {
                    let cleanDay = day.trimmingCharacters(in: .whitespaces)
                    if let ekDay = dayMap[cleanDay] {
                        daysOfTheWeek.append(EKRecurrenceDayOfWeek(dayOfTheWeek: ekDay, weekNumber: 0))
                    }
                }
            case "BYMONTHDAY":
                let days = value.split(separator: ",").compactMap { Int(String($0)) }
                daysOfTheMonth = days.map { NSNumber(value: $0) }
            case "COUNT":
                occurrenceCount = Int(value)
            case "UNTIL":
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                formatter.timeZone = TimeZone(identifier: "UTC")
                if let date = formatter.date(from: value) {
                    endDate = date
                } else {
                    formatter.dateFormat = "yyyyMMdd"
                    endDate = formatter.date(from: value)
                }
            default:
                break
            }
        }

        let recurrenceEnd: EKRecurrenceEnd?
        if let count = occurrenceCount {
            recurrenceEnd = EKRecurrenceEnd(occurrenceCount: count)
        } else if let end = endDate {
            recurrenceEnd = EKRecurrenceEnd(end: end)
        } else {
            recurrenceEnd = nil
        }

        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: daysOfTheWeek.isEmpty ? nil : daysOfTheWeek,
            daysOfTheMonth: daysOfTheMonth.isEmpty ? nil : daysOfTheMonth,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: recurrenceEnd
        )
    }
}
