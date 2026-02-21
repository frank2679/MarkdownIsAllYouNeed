import SwiftUI
import WebKit

struct MarkdownEditorView: UIViewRepresentable {
    let fileURL: URL
    let fileName: String
    @Binding var isDirty: Bool
    var onContentChanged: ((String) -> Void)?
    var onCoordinatorReady: ((Coordinator) -> Void)?
    var onModeChangeRequested: ((String) -> Void)?
    var onInternalLinkClicked: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "bridge")
        config.userContentController = userContentController

        // Allow file access for local images
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground

        // Load editor HTML from bundle
        // Files are added as a group (not folder reference), so they're in the bundle root
        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            // Fallback: inline HTML
            let html = Self.inlineEditorHTML()
            webView.loadHTMLString(html, baseURL: fileURL.deletingLastPathComponent())
        }

        context.coordinator.webView = webView
        DispatchQueue.main.async {
            self.onCoordinatorReady?(context.coordinator)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No dynamic updates needed — content is set via bridge after page loads
    }

    // Inline fallback HTML when bundle resources aren't found
    static func inlineEditorHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        :root { color-scheme: light dark; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: 16px; line-height: 1.6; padding: 16px;
            color: #1a1a1a; background: #fff;
        }
        @media (prefers-color-scheme: dark) {
            body { color: #e0e0e0; background: #1c1c1e; }
        }
        #editor { min-height: 100vh; outline: none; word-wrap: break-word; }
        #editor:empty::before { content: "Start writing..."; color: #999; font-style: italic; }
        #editor h1 { font-size: 28px; font-weight: 700; margin: 24px 0 12px; border-bottom: 1px solid #e0e0e0; padding-bottom: 8px; }
        #editor h2 { font-size: 22px; font-weight: 600; margin: 20px 0 10px; }
        #editor h3 { font-size: 18px; font-weight: 600; margin: 16px 0 8px; }
        #editor p { margin: 8px 0; }
        #editor strong { font-weight: 600; }
        #editor code { font-family: "SF Mono", Menlo, monospace; font-size: 14px; background: #f5f5f5; padding: 2px 6px; border-radius: 4px; }
        @media (prefers-color-scheme: dark) { #editor code { background: #2c2c2e; } }
        #editor pre { background: #f5f5f5; padding: 12px 16px; border-radius: 8px; margin: 12px 0; overflow-x: auto; }
        @media (prefers-color-scheme: dark) { #editor pre { background: #2c2c2e; } }
        #editor pre code { background: none; padding: 0; }
        #editor blockquote { border-left: 3px solid #d0d0d0; padding-left: 16px; margin: 12px 0; color: #666; }
        #editor ul, #editor ol { padding-left: 24px; margin: 8px 0; }
        #editor li { margin: 4px 0; }
        #editor hr { border: none; border-top: 1px solid #e0e0e0; margin: 16px 0; }
        #editor a { color: #0066cc; text-decoration: underline; }
        #editor img { max-width: 100%; height: auto; border-radius: 8px; margin: 8px 0; }
        #editor table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 14px; }
        #editor th, #editor td { border: 1px solid #e0e0e0; padding: 8px 12px; text-align: left; }
        #editor th { background: #f5f5f5; font-weight: 600; }
        </style>
        </head>
        <body>
        <div id="editor"></div>
        <script>
        \(editorJSSource())
        </script>
        </body>
        </html>
        """
    }

    private static func editorJSSource() -> String {
        if let jsURL = Bundle.main.url(forResource: "editor", withExtension: "js"),
           let js = try? String(contentsOf: jsURL) {
            return js
        }
        // Minimal inline JS bridge
        return """
        (function() {
            const editor = document.getElementById('editor');
            editor.contentEditable = true;
            editor.spellcheck = true;
            window.bridge = {
                receive: function(msg) {
                    if (msg.action === 'setContent') {
                        editor.innerText = msg.payload.markdown || '';
                    } else if (msg.action === 'getContent') {
                        try { webkit.messageHandlers.bridge.postMessage({ action: 'contentReady', version: 1, payload: { markdown: editor.innerText } }); } catch(e) {}
                    } else if (msg.action === 'formatText') {
                        document.execCommand(msg.payload.format === 'bold' ? 'bold' : msg.payload.format === 'italic' ? 'italic' : 'bold', false, null);
                    }
                }
            };
            editor.addEventListener('input', function() {
                try { webkit.messageHandlers.bridge.postMessage({ action: 'contentChanged', version: 1, payload: { markdown: editor.innerText, isDirty: true } }); } catch(e) {}
            });
            try { webkit.messageHandlers.bridge.postMessage({ action: 'editorReady', version: 1, payload: {} }); } catch(e) {}
        })();
        """
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: MarkdownEditorView
        var webView: WKWebView?
        private var contentLoaded = false

        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }

        // JS → Native bridge messages
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String,
                  let payload = body["payload"] as? [String: Any] else { return }

            switch action {
            case "editorReady":
                loadFileContent()

            case "contentChanged":
                DispatchQueue.main.async {
                    self.parent.isDirty = (payload["isDirty"] as? Bool) ?? true
                    if let markdown = payload["markdown"] as? String {
                        self.parent.onContentChanged?(markdown)
                    }
                }

            case "contentReady":
                if let markdown = payload["markdown"] as? String {
                    self.parent.onContentChanged?(markdown)
                }

            case "linkClicked":
                if let urlString = payload["url"] as? String {
                    DispatchQueue.main.async {
                        // Relative path (no scheme) → try in-app navigation
                        let isExternal = urlString.hasPrefix("http://")
                            || urlString.hasPrefix("https://")
                            || urlString.hasPrefix("mailto:")
                        if isExternal {
                            if let url = URL(string: urlString) {
                                UIApplication.shared.open(url)
                            }
                        } else {
                            self.parent.onInternalLinkClicked?(urlString)
                        }
                    }
                }

            case "modeChangeRequested":
                if let mode = payload["mode"] as? String {
                    DispatchQueue.main.async {
                        self.parent.onModeChangeRequested?(mode)
                    }
                }

            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Editor JS might not be ready yet — wait for editorReady message
        }

        private func loadFileContent() {
            guard !contentLoaded else { return }
            contentLoaded = true

            let markdown = FileManagerService.shared.readFileContent(at: parent.fileURL) ?? ""

            // Use JSONEncoder for safe string escaping (handles quotes, newlines, backslashes, etc.)
            let jsonString = (try? JSONEncoder().encode(markdown)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""

            // Set content then immediately switch to preview mode.
            // setMode must run after bridge is ready, so chain it here rather than in onCoordinatorReady.
            let js = """
                window.bridge.receive({ action: 'setContent', version: 1, payload: { markdown: \(jsonString) } });
                window.bridge.receive({ action: 'setMode', version: 1, payload: { mode: 'preview' } });
                """
            webView?.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("[Editor] JS evaluation error: \(error)")
                }
            }
        }

        // MARK: - Public methods for Native → JS

        func getContent() {
            let js = "window.bridge.receive({ action: 'getContent', version: 1, payload: {} });"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func applyFormat(_ format: String) {
            let js = "window.bridge.receive({ action: 'formatText', version: 1, payload: { format: '\(format)' } });"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func insertImage(path: String, alt: String) {
            let js = "window.bridge.receive({ action: 'insertImage', version: 1, payload: { path: '\(path)', alt: '\(alt)' } });"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func setMode(_ mode: String) {
            let js = "window.bridge.receive({ action: 'setMode', version: 1, payload: { mode: '\(mode)' } });"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
