import Foundation
import WebKit
import AppKit
import UniformTypeIdentifiers

/// Manages the export process: injecting JS into the WebView and handling the save dialog
@MainActor
class ExportManager: ObservableObject {
    private weak var webView: WKWebView?
    let exportState: ExportState

    init(exportState: ExportState) {
        self.exportState = exportState
    }

    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    /// Start the export by injecting the export script into the webview
    func startExport(includeArchived: Bool, includeAttachments: Bool) {
        guard let webView = webView else {
            exportState.phase = .error("WebView not available")
            return
        }

        exportState.reset()
        exportState.phase = .authenticating
        exportState.addLog("Starting export...")

        // Load the export JavaScript from the bundle
        guard let scriptURL = Bundle.main.url(forResource: "export-webview", withExtension: "js"),
              let scriptContent = try? String(contentsOf: scriptURL, encoding: .utf8) else {
            exportState.phase = .error("Export script not found in bundle")
            exportState.addLog("Failed to load export-webview.js from bundle", isError: true)
            return
        }

        // Inject options as a preamble
        let optionsJS = """
        window.__EXPORT_OPTIONS = {
            includeArchived: \(includeArchived),
            includeAttachments: \(includeAttachments)
        };
        """

        let fullScript = optionsJS + "\n" + scriptContent

        webView.evaluateJavaScript(fullScript) { [weak self] _, error in
            if let error = error {
                Task { @MainActor in
                    self?.exportState.phase = .error("Script injection failed: \(error.localizedDescription)")
                    self?.exportState.addLog("JS Error: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    /// Present a save dialog and write the export data to disk
    func saveExport() {
        guard let jsonString = exportState.exportData else {
            exportState.addLog("No export data available to save", isError: true)
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Save ChatGPT Export"
        savePanel.nameFieldStringValue = "chatgpt-export-\(Self.dateString()).json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                try jsonString.write(to: url, atomically: true, encoding: .utf8)
                Task { @MainActor in
                    self?.exportState.addLog("Saved to: \(url.path)")
                }
            } catch {
                Task { @MainActor in
                    self?.exportState.addLog("Save failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    /// Trigger a new login check
    func checkLogin() {
        guard let webView = webView else { return }

        let js = """
        (function() {
            fetch('https://chatgpt.com/api/auth/session', { credentials: 'include' })
                .then(r => r.json())
                .then(data => {
                    webkit.messageHandlers.loginStatus.postMessage({ loggedIn: !!data.accessToken });
                })
                .catch(() => {
                    webkit.messageHandlers.loginStatus.postMessage({ loggedIn: false });
                });
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Navigate the webview back to chatgpt.com
    func navigateHome() {
        guard let webView = webView else { return }
        if let url = URL(string: "https://chatgpt.com") {
            webView.load(URLRequest(url: url))
        }
    }

    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
