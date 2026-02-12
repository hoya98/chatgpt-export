import SwiftUI
import WebKit
import Combine

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var includeArchived = true
    @State private var includeAttachments = true
    @State private var showLog = false

    var body: some View {
        HSplitView {
            // Left side: WebView browser
            VStack(spacing: 0) {
                // Browser toolbar
                BrowserToolbar(exportManager: viewModel.exportManager, exportState: viewModel.exportState)

                // WebView
                ChatGPTWebView(exportState: viewModel.exportState) { webView in
                    viewModel.exportManager.setWebView(webView)
                }
            }
            .frame(minWidth: 500)

            // Right side: Export panel
            ExportSidebar(
                exportState: viewModel.exportState,
                exportManager: viewModel.exportManager,
                includeArchived: $includeArchived,
                includeAttachments: $includeAttachments,
                showLog: $showLog
            )
            .frame(width: 320)
        }
        .onReceive(viewModel.exportState.$exportData) { newValue in
            if newValue != nil {
                viewModel.exportManager.saveExport()
            }
        }
    }
}

/// Shared view model that owns both the ExportState and ExportManager
/// to ensure they share the same ExportState instance.
@MainActor
class ContentViewModel: ObservableObject {
    let exportState: ExportState
    let exportManager: ExportManager

    init() {
        let state = ExportState()
        self.exportState = state
        self.exportManager = ExportManager(exportState: state)
    }
}

// MARK: - Browser Toolbar

struct BrowserToolbar: View {
    @ObservedObject var exportManager: ExportManager
    @ObservedObject var exportState: ExportState

    var body: some View {
        HStack(spacing: 12) {
            // Navigation buttons
            Button(action: { exportManager.navigateHome() }) {
                Image(systemName: "house.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundColor(Color(hex: "10b981"))
            .help("Go to ChatGPT home")

            Spacer()

            // Login status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(exportState.isLoggedIn ? Color(hex: "10b981") : Color(hex: "ef4444"))
                    .frame(width: 8, height: 8)
                Text(exportState.isLoggedIn ? "Logged In" : "Not Logged In")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "888888"))
            }

            Button(action: { exportManager.checkLogin() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(Color(hex: "888888"))
            .help("Refresh login status")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "16213e"))
    }
}

// MARK: - Export Sidebar

struct ExportSidebar: View {
    @ObservedObject var exportState: ExportState
    @ObservedObject var exportManager: ExportManager
    @Binding var includeArchived: Bool
    @Binding var includeAttachments: Bool
    @Binding var showLog: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                SidebarHeader()

                // Status card
                StatusCard(phase: exportState.phase)

                // Stats
                StatsGrid(
                    conversations: exportState.conversationCount,
                    attachments: exportState.attachmentCount,
                    errors: exportState.errorCount
                )

                // Progress bar
                if let progress = exportState.phase.progress {
                    ProgressSection(
                        progress: progress,
                        title: exportState.currentConversationTitle,
                        phase: exportState.phase
                    )
                }

                // Options
                OptionsSection(
                    includeArchived: $includeArchived,
                    includeAttachments: $includeAttachments,
                    isDisabled: exportState.phase.isActive
                )

                // Export button
                ExportButton(
                    isActive: exportState.phase.isActive,
                    isLoggedIn: exportState.isLoggedIn,
                    isDone: exportState.phase.isDone
                ) {
                    exportManager.startExport(
                        includeArchived: includeArchived,
                        includeAttachments: includeAttachments
                    )
                }

                // Save again button (shown after export)
                if exportState.phase.isDone && exportState.exportData != nil {
                    Button(action: { exportManager.saveExport() }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Again...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                // Log toggle
                Button(action: { showLog.toggle() }) {
                    HStack {
                        Image(systemName: showLog ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                        Text("Activity Log (\(exportState.logMessages.count))")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hex: "888888"))
                }
                .buttonStyle(.plain)

                // Log area
                if showLog {
                    LogView(messages: exportState.logMessages)
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(hex: "1a1a2e"))
    }
}

// MARK: - Sidebar Header

struct SidebarHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "10b981"))

            VStack(alignment: .leading, spacing: 2) {
                Text("ChatGPT Export")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Bulk conversation exporter")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "888888"))
            }
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let phase: ExportPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATUS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(Color(hex: "888888"))

            Text(phase.statusText)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(statusColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "16213e"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "2a2a4a"), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch phase {
        case .idle:
            return Color(hex: "888888")
        case .done:
            return Color(hex: "10b981")
        case .error:
            return Color(hex: "ef4444")
        default:
            return Color(hex: "60a5fa")
        }
    }
}

// MARK: - Stats Grid

struct StatsGrid: View {
    let conversations: Int
    let attachments: Int
    let errors: Int

    var body: some View {
        HStack(spacing: 10) {
            StatBox(value: conversations > 0 ? "\(conversations)" : "-",
                    label: "Conversations",
                    color: Color(hex: "60a5fa"))
            StatBox(value: attachments > 0 ? "\(attachments)" : "-",
                    label: "Attachments",
                    color: Color(hex: "60a5fa"))
        }

        if errors > 0 {
            StatBox(value: "\(errors)", label: "Errors", color: Color(hex: "ef4444"))
                .frame(maxWidth: .infinity)
        }
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "888888"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "16213e"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "2a2a4a"), lineWidth: 1)
        )
    }
}

// MARK: - Progress Section

struct ProgressSection: View {
    let progress: Double
    let title: String
    let phase: ExportPhase

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "2a2a4a"))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "10b981"), Color(hex: "60a5fa")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text(progressText)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "888888"))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "60a5fa"))
            }

            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "666666"))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var progressText: String {
        switch phase {
        case .downloading(let current, let total):
            return "\(current) / \(total) conversations"
        case .downloadingAttachments(let current, let total):
            return "\(current) / \(total) attachments"
        default:
            return ""
        }
    }
}

// MARK: - Options Section

struct OptionsSection: View {
    @Binding var includeArchived: Bool
    @Binding var includeAttachments: Bool
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $includeArchived) {
                Text("Include archived conversations")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
            .toggleStyle(.checkbox)
            .tint(Color(hex: "10b981"))
            .disabled(isDisabled)

            Toggle(isOn: $includeAttachments) {
                Text("Track file attachments")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
            .toggleStyle(.checkbox)
            .tint(Color(hex: "10b981"))
            .disabled(isDisabled)
        }
    }
}

// MARK: - Export Button

struct ExportButton: View {
    let isActive: Bool
    let isLoggedIn: Bool
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isActive {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isDone ? "arrow.clockwise" : "arrow.down.doc.fill")
                }
                Text(isDone ? "Export Again" : "Export All Conversations")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isActive || !isLoggedIn)
    }
}

// MARK: - Log View

struct LogView: View {
    let messages: [ExportState.LogEntry]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(messages) { entry in
                        Text(entry.message)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(entry.isError ? Color(hex: "ef4444") : Color(hex: "7ee787"))
                            .textSelection(.enabled)
                            .id(entry.id)
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: 200)
            .background(Color(hex: "0d1117"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "2a2a4a"), lineWidth: 1)
            )
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                Group {
                    if isEnabled {
                        LinearGradient(
                            colors: [Color(hex: "10b981"), Color(hex: "059669")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color(hex: "2a2a4a")
                    }
                }
            )
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color(hex: "e0e0e0"))
            .background(Color(hex: "16213e"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "2a2a4a"), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: 1100, height: 750)
}
