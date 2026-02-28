import SwiftUI
import UIKit
import WebKit

// MARK: - LocalFileSchemeHandler
// Serves local files under the app sandbox via the "localfile://" custom scheme,
// bypassing WKWebView's file:// access restrictions for inline-loaded HTML pages.

class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let filePath = url.path
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            let data = try Data(contentsOf: fileURL)
            let mimeType = Self.mimeType(for: url.pathExtension)
            let response = URLResponse(url: url, mimeType: mimeType,
                                       expectedContentLength: data.count,
                                       textEncodingName: nil)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png":  return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif":  return "image/gif"
        case "webp": return "image/webp"
        case "svg":  return "image/svg+xml"
        default:     return "application/octet-stream"
        }
    }
}

// MARK: - KeyboardAccessoryWebView

class KeyboardAccessoryWebView: WKWebView {
    var accessoryView: UIView?
    override var inputAccessoryView: UIView? { accessoryView }
}

// MARK: - MarkdownEditorView

struct MarkdownEditorView: UIViewRepresentable {
    let fileURL: URL
    let fileName: String
    @Binding var isDirty: Bool
    var onContentChanged: ((String) -> Void)?
    var onCoordinatorReady: ((Coordinator) -> Void)?
    var onModeChangeRequested: ((String) -> Void)?
    var onInternalLinkClicked: ((String) -> Void)?
    var onImageClicked: ((URL) -> Void)?
    var fontSize: Int = 16

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> KeyboardAccessoryWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "bridge")
        config.userContentController = userContentController

        // Register custom scheme handler so inline-loaded pages can serve local repo images
        config.setURLSchemeHandler(LocalFileSchemeHandler(), forURLScheme: "localfile")

        let webView = KeyboardAccessoryWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground

        // EditorToolbar as inputAccessoryView (appears above keyboard)
        let toolbarHost = UIHostingController(
            rootView: EditorToolbar(
                onFormat: { [weak coordinator = context.coordinator] format in
                    coordinator?.applyFormat(format)
                },
                onDismissKeyboard: { [weak webView] in
                    webView?.endEditing(true)
                }
            )
        )
        toolbarHost.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
        toolbarHost.view.autoresizingMask = .flexibleWidth
        toolbarHost.view.backgroundColor = .clear
        context.coordinator.toolbarHostingController = toolbarHost
        webView.accessoryView = toolbarHost.view

        // Load editor HTML inline with baseURL pointing to the file's directory.
        // This allows relative image paths (e.g. ./image.png) to resolve correctly
        // from the repo directory, without needing separate allowingReadAccessTo config.
        let html = Self.inlineEditorHTML()
        webView.loadHTMLString(html, baseURL: fileURL.deletingLastPathComponent())

        context.coordinator.webView = webView
        DispatchQueue.main.async {
            self.onCoordinatorReady?(context.coordinator)
        }
        return webView
    }

    func updateUIView(_ uiView: KeyboardAccessoryWebView, context: Context) {
        // No dynamic updates needed — content is set via bridge after page loads
    }

    // Inline HTML with CSS and JS from bundle resources
    static func inlineEditorHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        \(editorCSSSource())
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

    private static func editorCSSSource() -> String {
        if let cssURL = Bundle.main.url(forResource: "editor", withExtension: "css"),
           let css = try? String(contentsOf: cssURL) {
            return css
        }
        // Minimal fallback
        return """
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, sans-serif; font-size: 16px; line-height: 1.6; padding: 16px; }
        #editor { min-height: 100vh; outline: none; word-wrap: break-word; }
        #editor h1 { font-size: 1.75em; font-weight: 700; }
        #editor h2 { font-size: 1.375em; font-weight: 600; }
        #editor h3 { font-size: 1.125em; font-weight: 600; }
        #editor img { max-width: 100%; height: auto; }
        #editor a { color: #0066cc; text-decoration: underline; }
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
                    } else if (msg.action === 'setFontSize') {
                        document.body.style.fontSize = msg.payload.size + 'px';
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
        var toolbarHostingController: UIViewController?  // retains toolbar host
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

            case "imageClicked":
                if let urlString = payload["url"] as? String, let url = URL(string: urlString) {
                    DispatchQueue.main.async {
                        self.parent.onImageClicked?(url)
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
            let basePath = parent.fileURL.deletingLastPathComponent().path

            // Use JSONSerialization so both markdown and basePath are safely escaped
            let payload: [String: Any] = ["markdown": markdown, "basePath": basePath]
            guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
                  let payloadJSON = String(data: payloadData, encoding: .utf8) else { return }

            let initialFontSize = parent.fontSize

            // Set content, switch to preview, and apply initial font size
            let js = """
                window.bridge.receive({ action: 'setContent', version: 1, payload: \(payloadJSON) });
                window.bridge.receive({ action: 'setMode', version: 1, payload: { mode: 'preview' } });
                window.bridge.receive({ action: 'setFontSize', version: 1, payload: { size: \(initialFontSize) } });
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

        func setFontSize(_ size: Int) {
            let js = "window.bridge.receive({ action: 'setFontSize', version: 1, payload: { size: \(size) } });"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func undo() {
            let js = "window.bridge.receive({ action: 'undo', version: 1, payload: {} });"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func redo() {
            let js = "window.bridge.receive({ action: 'redo', version: 1, payload: {} });"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func getRenderedHTML(completion: @escaping (String?) -> Void) {
            webView?.evaluateJavaScript("document.getElementById('editor')?.innerHTML ?? ''") { result, _ in
                completion(result as? String)
            }
        }

        /// Reload content into WebView if the editor is empty (e.g. after iOS killed the Web Process).
        /// Prefers in-memory markdown to avoid losing unsaved edits; falls back to disk.
        func reloadContentIfEmpty(fallbackMarkdown: String, fontSize: Int) {
            webView?.evaluateJavaScript(
                "document.getElementById('editor')?.innerHTML ?? ''"
            ) { [weak self] result, _ in
                guard let self else { return }
                let html = (result as? String) ?? ""
                let isEmpty = html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || html == "<br>" || html == "<br/>"
                guard isEmpty else { return }

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let markdown = fallbackMarkdown.isEmpty
                        ? (FileManagerService.shared.readFileContent(at: self.parent.fileURL) ?? "")
                        : fallbackMarkdown
                    let basePath = self.parent.fileURL.deletingLastPathComponent().path
                    let payload: [String: Any] = ["markdown": markdown, "basePath": basePath]
                    guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
                          let payloadJSON = String(data: payloadData, encoding: .utf8) else { return }
                    let js = """
                        window.bridge.receive({ action: 'setContent', version: 1, payload: \(payloadJSON) });
                        window.bridge.receive({ action: 'setMode', version: 1, payload: { mode: 'preview' } });
                        window.bridge.receive({ action: 'setFontSize', version: 1, payload: { size: \(fontSize) } });
                        """
                    self.webView?.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }
    }
}
