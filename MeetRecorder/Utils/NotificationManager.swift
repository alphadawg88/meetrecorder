import UserNotifications

struct NotificationManager {
    static func register() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        let startAction = UNNotificationAction(identifier: "START_RECORDING", title: "Start Recording", options: [.foreground])
        // Calendar meeting-start prompt and the live call-detect prompt share the
        // same "Start Recording" action; both categories route to it.
        let meetingStart = UNNotificationCategory(identifier: "MEETING_START", actions: [startAction], intentIdentifiers: [], options: [])
        let callDetected = UNNotificationCategory(identifier: "CALL_DETECTED", actions: [startAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([meetingStart, callDetected])
    }

    static func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// A prompt with a "Start Recording" action button (used by the call detector).
    /// The optional fixed identifier lets us avoid stacking duplicate prompts.
    static func notifyWithStartAction(title: String, body: String, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "CALL_DETECTED"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let category = response.notification.request.content.categoryIdentifier
        if response.actionIdentifier == "START_RECORDING"
            || category == "MEETING_START"
            || category == "CALL_DETECTED" {
            NotificationCenter.default.post(name: .toggleRecording, object: nil)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
