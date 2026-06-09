import EventKit
import Combine
import UserNotifications

@MainActor
final class CalendarManager: ObservableObject {
    @Published var upcomingEvent: EKEvent?
    @Published var hasAccess: Bool = false

    private let eventStore = EKEventStore()
    private var timer: Timer?
    private var notifiedEventIDs: Set<String> = []

    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted { self?.startMonitoring() }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted { self?.startMonitoring() }
                }
            }
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            // Timer callbacks are nonisolated; hop to the main actor before touching state.
            Task { @MainActor in self?.checkUpcomingEvents() }
        }
        checkUpcomingEvents()
    }

    func checkUpcomingEvents() {
        guard hasAccess else { return }
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let predicate = eventStore.predicateForEvents(withStart: now, end: now.addingTimeInterval(3600), calendars: calendars)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        // Surface the next future event (within the hour) for the UI card…
        if let next = events.first(where: { $0.startDate > now }) {
            if upcomingEvent?.eventIdentifier != next.eventIdentifier {
                upcomingEvent = next
            }
            // …but only notify once, when it's within five minutes of starting.
            if let id = next.eventIdentifier,
               next.startDate.timeIntervalSince(now) <= 300,
               !notifiedEventIDs.contains(id) {
                notifiedEventIDs.insert(id)
                notifyMeetingStart(event: next)
            }
        } else {
            upcomingEvent = nil
        }
    }

    func eventEndDate(for eventID: String) -> Date? {
        guard let event = eventStore.event(withIdentifier: eventID) else { return nil }
        return event.endDate
    }

    private func notifyMeetingStart(event: EKEvent) {
        guard SettingsStore.shared.calendarReminders else { return }
        let content = UNMutableNotificationContent()
        content.title = "Meeting Starting Soon"
        content.body = "\(event.title ?? "Meeting") begins at \(event.startDate.formatted(date: .omitted, time: .shortened)). Start recording?"
        content.sound = .default
        content.categoryIdentifier = "MEETING_START"

        let request = UNNotificationRequest(identifier: "meeting-\(event.eventIdentifier ?? UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
