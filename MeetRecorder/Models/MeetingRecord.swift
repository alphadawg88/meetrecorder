import Foundation

struct MeetingRecord: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let title: String
    let calendarEventID: String?
    let audioURL: URL?
    let markdownURL: URL?
    let status: RecordingStatus

    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "In progress" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

enum RecordingStatus: String, Codable {
    case recording
    case processing
    case completed
    case failed
}

struct AIOutput: Codable {
    let executiveSummary: String
    let keyTakeaways: [String]
    let actionItems: [ActionItem]
    let detailedNotes: String
    let translatedTranscript: String
}

struct ActionItem: Codable {
    let task: String
    let owner: String?
    let dueDate: String?
}
