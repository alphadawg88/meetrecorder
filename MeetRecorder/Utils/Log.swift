import Foundation
import os

/// Lightweight file logger for debugging.
///
/// Writes timestamped lines to `~/Library/Logs/Glyph/glyph.log` (tail it live
/// while reproducing a bug) and mirrors to the unified log (Console.app,
/// subsystem `com.alfredwong.glyph`). Thread-safe via a serial queue.
///
/// It also installs an uncaught-exception handler so that an Objective-C
/// exception (e.g. AVAssetWriter throwing) records its *reason* to the log
/// before the process aborts — the crash report (.ips) does not keep that string.
enum Log {
    /// Stable, easy-to-tail location: ~/Library/Logs/Glyph/glyph.log
    static let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Glyph", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("glyph.log")
    }()

    private static let osLog = Logger(subsystem: "com.alfredwong.glyph", category: "app")
    private static let queue = DispatchQueue(label: "com.alfredwong.glyph.log")
    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func info(_ msg: String, file: String = #fileID, line: Int = #line)  { write("INFO",  msg, file, line) }
    static func warn(_ msg: String, file: String = #fileID, line: Int = #line)  { write("WARN",  msg, file, line) }
    static func error(_ msg: String, file: String = #fileID, line: Int = #line) { write("ERROR", msg, file, line) }

    private static func write(_ level: String, _ msg: String, _ file: String, _ line: Int) {
        let short = (file as NSString).lastPathComponent
        let stamp = stampFormatter.string(from: Date())
        let entry = "\(stamp) [\(level)] \(short):\(line)  \(msg)\n"

        // Mirror to the unified log so it's visible in Console.app too.
        switch level {
        case "ERROR": osLog.error("\(short):\(line) \(msg, privacy: .public)")
        case "WARN":  osLog.warning("\(short):\(line) \(msg, privacy: .public)")
        default:      osLog.info("\(short):\(line) \(msg, privacy: .public)")
        }

        queue.async {
            if let h = try? FileHandle(forWritingTo: fileURL) {
                defer { try? h.close() }
                _ = try? h.seekToEnd()
                try? h.write(contentsOf: Data(entry.utf8))
            } else {
                // First write — create the file.
                try? Data(entry.utf8).write(to: fileURL)
            }
        }
    }

    /// Truncate the log if it grows past ~5 MB so it stays tail-able. Call at launch.
    static func rotateIfNeeded() {
        queue.async {
            let path = fileURL.path
            if let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int,
               size > 5_000_000 {
                try? Data().write(to: fileURL)
            }
        }
    }

    /// Record uncaught Objective-C exceptions (with their reason + stack) to the
    /// log before the process aborts. The crash report omits the reason string,
    /// so this is what tells us *why* something like AVAssetWriter threw.
    static func installExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let name = exception.name.rawValue
            let reason = exception.reason ?? "(no reason)"
            let stack = exception.callStackSymbols.joined(separator: "\n  ")
            Log.error("UNCAUGHT EXCEPTION \(name): \(reason)\n  \(stack)")
            // Give the async file write a moment to flush before abort.
            Log.queue.sync {}
        }
    }
}
