import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/file_manager_service.dart';
import '../../providers/file_tree_provider.dart';
import 'package:provider/provider.dart';

class MarkdownEditorScreen extends StatefulWidget {
  final String filePath;
  final String relativePath;

  const MarkdownEditorScreen({
    super.key,
    required this.filePath,
    required this.relativePath,
  });

  @override
  State<MarkdownEditorScreen> createState() => _MarkdownEditorScreenState();
}

class _MarkdownEditorScreenState extends State<MarkdownEditorScreen> {
  late final WebViewController _webViewController;
  bool _isPreview = false;
  bool _isLoaded = false;
  bool _isDirty = false;
  String _currentContent = '';

  @override
  void initState() {
    super.initState();
    _currentContent =
        FileManagerService.shared.readFileContent(widget.filePath) ?? '';
    _setupWebView();
  }

  void _setupWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ContentChanged',
        onMessageReceived: (msg) {
          _currentContent = msg.message;
          if (!_isDirty) setState(() => _isDirty = true);
        },
      )
      ..addJavaScriptChannel(
        'LinkClicked',
        onMessageReceived: (msg) => _handleLinkClick(msg.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _isLoaded = true;
          _injectContent();
        },
      ))
      ..loadFlutterAsset('assets/editor/index.html');
  }

  void _injectContent() {
    final escaped = jsonEncode(_currentContent);
    _webViewController.runJavaScript('loadContent($escaped)');
    _setMode(_isPreview);
  }

  void _setMode(bool preview) {
    _webViewController.runJavaScript(
        'setMode(${preview ? '"preview"' : '"edit"'})');
  }

  Future<void> _save() async {
    if (!_isDirty) return;
    FileManagerService.shared.writeFileContent(
        _currentContent, widget.filePath);
    setState(() => _isDirty = false);
    context.read<FileTreeProvider>().refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)),
    );
  }

  void _handleLinkClick(String link) {
    // Internal wiki-link navigation: [[file]] style
    if (link.startsWith('[[') && link.endsWith(']]')) {
      // Internal wiki-link: could navigate to target file
    }
    // External URLs ignored for now
  }

  @override
  void dispose() {
    if (_isDirty) {
      FileManagerService.shared.writeFileContent(
          _currentContent, widget.filePath);
      context.read<FileTreeProvider>().refresh();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.filePath.split('/').last;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(name, overflow: TextOverflow.ellipsis),
            ),
            if (_isDirty)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isPreview ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: _isPreview ? 'Edit' : 'Preview',
            onPressed: () {
              setState(() => _isPreview = !_isPreview);
              if (_isLoaded) _setMode(_isPreview);
            },
          ),
          if (_isDirty)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isPreview) _EditorToolbar(webViewController: _webViewController),
          Expanded(child: WebViewWidget(controller: _webViewController)),
        ],
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  final WebViewController webViewController;

  const _EditorToolbar({required this.webViewController});

  void _exec(String cmd) {
    webViewController.runJavaScript('formatCommand("$cmd")');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      color: theme.colorScheme.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _ToolbarButton(label: 'H1', onPressed: () => _exec('h1')),
            _ToolbarButton(label: 'H2', onPressed: () => _exec('h2')),
            _ToolbarButton(label: 'H3', onPressed: () => _exec('h3')),
            _ToolbarDivider(),
            _ToolbarIconButton(icon: Icons.format_bold, onPressed: () => _exec('bold')),
            _ToolbarIconButton(icon: Icons.format_italic, onPressed: () => _exec('italic')),
            _ToolbarIconButton(
                icon: Icons.format_strikethrough,
                onPressed: () => _exec('strikethrough')),
            _ToolbarDivider(),
            _ToolbarIconButton(
                icon: Icons.format_list_bulleted,
                onPressed: () => _exec('ul')),
            _ToolbarIconButton(
                icon: Icons.format_list_numbered,
                onPressed: () => _exec('ol')),
            _ToolbarDivider(),
            _ToolbarIconButton(
                icon: Icons.code, onPressed: () => _exec('code')),
            _ToolbarIconButton(
                icon: Icons.format_quote,
                onPressed: () => _exec('blockquote')),
            _ToolbarIconButton(
                icon: Icons.link, onPressed: () => _exec('link')),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ToolbarIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Theme.of(context).dividerColor,
    );
  }
}
