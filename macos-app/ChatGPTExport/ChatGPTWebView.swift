import SwiftUI
import WebKit

/// A SwiftUI wrapper around WKWebView that loads chatgpt.com and handles export injection
struct ChatGPTWebView: NSViewRepresentable {
    @ObservedObject var exportState: ExportState
    let onWebViewCreated: (WKWebView) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Set up the user content controller for message handling
        let contentController = WKUserContentController()

        // Register message handlers for communication from JS -> Swift
        let messageNames = [
            "exportLog",
            "exportStatus",
            "exportProgress",
            "exportStats",
            "exportDone",
            "exportError",
            "exportData",
            "loginStatus"
        ]
        for name in messageNames {
            contentController.add(context.coordinator, name: name)
        }

        config.userContentController = contentController

        // Allow JavaScript
        config.preferences.setValue(true, forKey: "javaScriptCanOpenWindowsAutomatically")

        // Set up data store for persistent cookies (login persistence)
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Custom user agent to avoid bot detection
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // Load ChatGPT
        if let url = URL(string: "https://chatgpt.com") {
            webView.load(URLRequest(url: url))
        }

        // Store reference for later use
        context.coordinator.webView = webView
        onWebViewCreated(webView)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed - the webview manages its own state
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(exportState: exportState)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var webView: WKWebView?
        let exportState: ExportState

        init(exportState: ExportState) {
            self.exportState = exportState
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Check if we're on chatgpt.com and likely logged in
            checkLoginStatus(webView: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                exportState.addLog("Navigation error: \(error.localizedDescription)", isError: true)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            // Allow all navigation within chatgpt.com domain
            if let url = navigationAction.request.url {
                let host = url.host ?? ""
                if host.contains("chatgpt.com") || host.contains("openai.com") || host.contains("auth0.com") || host.contains("google.com") || host.contains("apple.com") || host.contains("microsoft.com") || host.contains("live.com") || host.contains("microsoftonline.com") {
                    return .allow
                }
                // Allow other navigation too (for OAuth flows)
                return .allow
            }
            return .allow
        }

        // MARK: - Login Check

        private func checkLoginStatus(webView: WKWebView) {
            let js = """
            (function() {
                try {
                    fetch('https://chatgpt.com/api/auth/session', { credentials: 'include' })
                        .then(r => r.json())
                        .then(data => {
                            if (data.accessToken) {
                                webkit.messageHandlers.loginStatus.postMessage({ loggedIn: true });
                            } else {
                                webkit.messageHandlers.loginStatus.postMessage({ loggedIn: false });
                            }
                        })
                        .catch(() => {
                            webkit.messageHandlers.loginStatus.postMessage({ loggedIn: false });
                        });
                } catch(e) {
                    webkit.messageHandlers.loginStatus.postMessage({ loggedIn: false });
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }

            Task { @MainActor in
                switch message.name {
                case "loginStatus":
                    if let loggedIn = body["loggedIn"] as? Bool {
                        exportState.isLoggedIn = loggedIn
                    }

                case "exportLog":
                    if let text = body["text"] as? String {
                        let isError = body["isError"] as? Bool ?? false
                        exportState.addLog(text, isError: isError)
                    }

                case "exportStatus":
                    if let status = body["status"] as? String {
                        switch status {
                        case "authenticating":
                            exportState.phase = .authenticating
                        case "listing":
                            exportState.phase = .listing
                        case "downloading":
                            let current = body["current"] as? Int ?? 0
                            let total = body["total"] as? Int ?? 0
                            exportState.phase = .downloading(current: current, total: total)
                        case "attachments":
                            let current = body["current"] as? Int ?? 0
                            let total = body["total"] as? Int ?? 0
                            exportState.phase = .downloadingAttachments(current: current, total: total)
                        case "packaging":
                            exportState.phase = .packaging
                        case "done":
                            exportState.phase = .done
                        case "error":
                            let msg = body["message"] as? String ?? "Unknown error"
                            exportState.phase = .error(msg)
                        default:
                            break
                        }
                    }

                case "exportProgress":
                    if let current = body["current"] as? Int, let total = body["total"] as? Int {
                        if exportState.phase.isActive {
                            // Update the download phase with new counts
                            if case .downloadingAttachments = exportState.phase {
                                exportState.phase = .downloadingAttachments(current: current, total: total)
                            } else {
                                exportState.phase = .downloading(current: current, total: total)
                            }
                        }
                    }

                case "exportStats":
                    if let conversations = body["conversations"] as? Int {
                        exportState.conversationCount = conversations
                    }
                    if let attachments = body["attachments"] as? Int {
                        exportState.attachmentCount = attachments
                    }
                    if let errors = body["errors"] as? Int {
                        exportState.errorCount = errors
                    }
                    if let title = body["currentTitle"] as? String {
                        exportState.currentConversationTitle = title
                    }

                case "exportDone":
                    if let conversations = body["conversations"] as? Int {
                        exportState.conversationCount = conversations
                    }
                    if let attachments = body["attachments"] as? Int {
                        exportState.attachmentCount = attachments
                    }
                    if let errors = body["errors"] as? Int {
                        exportState.errorCount = errors
                    }
                    if let sizeMB = body["sizeMB"] as? Int {
                        exportState.exportSizeMB = sizeMB
                    }
                    exportState.phase = .done

                case "exportError":
                    if let text = body["text"] as? String {
                        exportState.phase = .error(text)
                        exportState.addLog("ERROR: \(text)", isError: true)
                    }

                case "exportData":
                    if let data = body["data"] as? String {
                        exportState.exportData = data
                    }

                default:
                    break
                }
            }
        }
    }
}
