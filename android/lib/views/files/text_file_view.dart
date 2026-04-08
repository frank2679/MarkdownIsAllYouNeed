import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_node.dart';
import '../../providers/file_tree_provider.dart';
import '../../services/file_manager_service.dart';

class TextFileView extends StatefulWidget {
  final String filePath;
  final String relativePath;
  final FileType fileType;

  const TextFileView({
    super.key,
    required this.filePath,
    required this.relativePath,
    required this.fileType,
  });

  @override
  State<TextFileView> createState() => _TextFileViewState();
}

class _TextFileViewState extends State<TextFileView> {
  late TextEditingController _controller;
  bool _isDirty = false;
  bool _showSavedToast = false;

  @override
  void initState() {
    super.initState();
    final content =
        FileManagerService.shared.readFileContent(widget.filePath) ?? '';
    _controller = TextEditingController(text: content);
    _controller.addListener(() {
      if (!_isDirty) setState(() => _isDirty = true);
    });
  }

  @override
  void dispose() {
    if (_isDirty) {
      FileManagerService.shared.writeFileContent(
          _controller.text, widget.filePath);
      context.read<FileTreeProvider>().refresh();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FileManagerService.shared.writeFileContent(
        _controller.text, widget.filePath);
    context.read<FileTreeProvider>().refresh();
    setState(() {
      _isDirty = false;
      _showSavedToast = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _showSavedToast = false);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.filePath.split('/').last;
    final isEditable = widget.fileType == FileType.markdown ||
        widget.fileType == FileType.text;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
                child: Text(name, overflow: TextOverflow.ellipsis)),
            if (_isDirty && isEditable)
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
          if (_isDirty && isEditable)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _save,
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: isEditable
                ? TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 14),
                    decoration: const InputDecoration(
                        border: InputBorder.none),
                  )
                : SingleChildScrollView(
                    child: Text(
                      _controller.text,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 14),
                    ),
                  ),
          ),
          if (_showSavedToast)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Saved',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
