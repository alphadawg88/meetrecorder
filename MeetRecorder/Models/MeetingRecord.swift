import Foundation

struct MeetingRecord: Identifiable, Codable, Equatable {
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

    enum CodingKeys: String, CodingKey {
        case executiveSummary, keyTakeaways, actionItems, detailedNotes, translatedTranscript
    }

    init(executiveSummary: String, keyTakeaways: [String], actionItems: [ActionItem],
         detailedNotes: String, translatedTranscript: String) {
        self.executiveSummary = executiveSummary
        self.keyTakeaways = keyTakeaways
        self.actionItems = actionItems
        self.detailedNotes = detailedNotes
        self.translatedTranscript = translatedTranscript
    }

    // Tolerant decoding: small on-device models often return the right content
    // in the wrong JSON shape (e.g. `detailed_notes` as an object, or a takeaway
    // as an object). Decode each field flexibly so a single shape mismatch can't
    // throw away the whole summary and force the raw-text fallback.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func flexString(_ key: CodingKeys) -> String {
            if let s = try? c.decode(String.self, forKey: key) { return s }
            if let v = try? c.decode(JSONValue.self, forKey: key) { return v.asText() }
            return ""
        }
        executiveSummary = flexString(.executiveSummary)
        detailedNotes = flexString(.detailedNotes)
        translatedTranscript = flexString(.translatedTranscript)

        if let arr = try? c.decode([String].self, forKey: .keyTakeaways) {
            keyTakeaways = arr
        } else if let v = try? c.decode(JSONValue.self, forKey: .keyTakeaways),
                  case .array(let items) = v {
            keyTakeaways = items.map { $0.asText() }.filter { !$0.isEmpty }
        } else {
            keyTakeaways = []
        }

        actionItems = (try? c.decode([ActionItem].self, forKey: .actionItems)) ?? []
    }
}

struct ActionItem: Codable {
    let task: String
    let owner: String?
    let dueDate: String?
}

/// Minimal JSON value used to tolerantly decode fields a local model may return
/// in an unexpected shape, then render them to readable text.
private enum JSONValue: Decodable {
    case string(String), number(Double), bool(Bool), null
    case array([JSONValue]), object([(String, JSONValue)])

    init(from decoder: Decoder) throws {
        if let c = try? decoder.singleValueContainer() {
            if c.decodeNil() { self = .null; return }
            if let b = try? c.decode(Bool.self) { self = .bool(b); return }
            if let n = try? c.decode(Double.self) { self = .number(n); return }
            if let s = try? c.decode(String.self) { self = .string(s); return }
        }
        if var arr = try? decoder.unkeyedContainer() {
            var items: [JSONValue] = []
            while !arr.isAtEnd { items.append(try arr.decode(JSONValue.self)) }
            self = .array(items); return
        }
        if let obj = try? decoder.container(keyedBy: JSONKey.self) {
            var pairs: [(String, JSONValue)] = []
            for k in obj.allKeys { pairs.append((k.stringValue, try obj.decode(JSONValue.self, forKey: k))) }
            self = .object(pairs); return
        }
        self = .null
    }

    /// Render to readable markdown-ish text (objects → **Title**: value, arrays → bullets).
    func asText(indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        switch self {
        case .string(let s):  return s
        case .number(let n):  return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b):    return b ? "true" : "false"
        case .null:           return ""
        case .array(let items):
            return items.map { "\(pad)- \($0.asText(indent: indent + 1))" }.joined(separator: "\n")
        case .object(let pairs):
            return pairs.map { key, val in
                let title = JSONValue.humanize(key)
                let body = val.asText(indent: indent + 1)
                return body.contains("\n") ? "\(pad)**\(title)**\n\(body)" : "\(pad)**\(title)**: \(body)"
            }.joined(separator: "\n")
        }
    }

    /// "snake_case" or "camelCase" → "Title Case Words" (decoder may camelCase
    /// nested keys via convertFromSnakeCase, so handle both).
    static func humanize(_ key: String) -> String {
        var words: [String] = []
        var current = ""
        for ch in key {
            if ch == "_" || ch == "-" || ch == " " {
                if !current.isEmpty { words.append(current); current = "" }
            } else if ch.isUppercase, let last = current.last, last.isLowercase {
                words.append(current); current = String(ch)
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

private struct JSONKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
}
