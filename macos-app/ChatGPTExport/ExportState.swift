import Foundation
import Combine

/// Represents the current phase of the export process
enum ExportPhase: Equatable {
    case idle
    case authenticating
    case listing
    case downloading(current: Int, total: Int)
    case downloadingAttachments(current: Int, total: Int)
    case packaging
    case done
    case error(String)

    var statusText: String {
        switch self {
        case .idle:
            return "Ready"
        case .authenticating:
            return "Authenticating..."
        case .listing:
            return "Listing Conversations..."
        case .downloading(let current, let total):
            return "Downloading \(current)/\(total)..."
        case .downloadingAttachments(let current, let total):
            return "Attachments \(current)/\(total)..."
        case .packaging:
            return "Packaging..."
        case .done:
            return "Export Complete!"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }

    var isActive: Bool {
        switch self {
        case .idle, .done, .error:
            return false
        default:
            return true
        }
    }

    var isDone: Bool {
        if case .done = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var progress: Double? {
        switch self {
        case .downloading(let current, let total):
            guard total > 0 else { return nil }
            return Double(current) / Double(total)
        case .downloadingAttachments(let current, let total):
            guard total > 0 else { return nil }
            return Double(current) / Double(total)
        default:
            return nil
        }
    }
}

/// Observable state object shared between the WebView coordinator and the SwiftUI views
@MainActor
class ExportState: ObservableObject {
    @Published var phase: ExportPhase = .idle
    @Published var conversationCount: Int = 0
    @Published var attachmentCount: Int = 0
    @Published var errorCount: Int = 0
    @Published var logMessages: [LogEntry] = []
    @Published var isLoggedIn: Bool = false
    @Published var exportData: String? = nil
    @Published var currentConversationTitle: String = ""
    @Published var exportSizeMB: Int = 0

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let isError: Bool

        init(_ message: String, isError: Bool = false) {
            self.timestamp = Date()
            self.message = message
            self.isError = isError
        }
    }

    func addLog(_ message: String, isError: Bool = false) {
        logMessages.append(LogEntry(message, isError: isError))
        // Keep only last 500 messages to prevent memory issues
        if logMessages.count > 500 {
            logMessages.removeFirst(logMessages.count - 500)
        }
    }

    func reset() {
        phase = .idle
        conversationCount = 0
        attachmentCount = 0
        errorCount = 0
        logMessages.removeAll()
        exportData = nil
        currentConversationTitle = ""
        exportSizeMB = 0
    }
}
