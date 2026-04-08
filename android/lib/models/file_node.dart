import 'git_status.dart';

enum FileType {
  markdown,
  text,
  image,
  binary;

  String get iconName {
    switch (this) {
      case FileType.markdown:
        return 'description';
      case FileType.text:
        return 'article';
      case FileType.image:
        return 'image';
      case FileType.binary:
        return 'insert_drive_file';
    }
  }
}

class FileNode implements Comparable<FileNode> {
  final String name;
  final String path;
  final bool isDirectory;
  final FileType fileType;
  List<FileNode>? children;
  bool isExpanded;
  FileChangeType? changeType;

  FileNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.fileType,
    this.children,
    this.isExpanded = false,
    this.changeType,
  });

  @override
  int compareTo(FileNode other) {
    if (isDirectory != other.isDirectory) {
      return isDirectory ? -1 : 1;
    }
    return name.toLowerCase().compareTo(other.name.toLowerCase());
  }
}

abstract final class FileTypeDetector {
  const FileTypeDetector._();

  static const _markdownExtensions = {
    'md', 'markdown', 'mdown', 'mkd'
  };

  static const _textExtensions = {
    'txt', 'swift', 'js', 'ts', 'json', 'xml', 'html', 'css', 'yml', 'yaml',
    'toml', 'ini', 'cfg', 'conf', 'sh', 'bash', 'zsh', 'py', 'rb', 'go',
    'rs', 'c', 'cpp', 'h', 'hpp', 'java', 'kt', 'm', 'mm', 'r', 'sql',
    'graphql', 'proto', 'makefile', 'dockerfile', 'gitignore', 'gitattributes',
    'editorconfig', 'env', 'lock', 'log', 'csv', 'tsv', 'dart',
  };

  static const _imageExtensions = {
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'svg', 'webp', 'ico', 'heic', 'heif', 'tiff',
  };

  static const _knownTextFiles = {
    'readme', 'license', 'makefile', 'dockerfile', 'gemfile',
    'rakefile', 'podfile', 'cartfile', '.gitignore', '.gitattributes',
    '.editorconfig', '.env',
  };

  static FileType detect(String filename) {
    final lower = filename.toLowerCase();
    final dotIdx = lower.lastIndexOf('.');
    final ext = dotIdx >= 0 ? lower.substring(dotIdx + 1) : '';
    final baseName = lower.split('/').last;

    if (_markdownExtensions.contains(ext)) return FileType.markdown;
    if (_imageExtensions.contains(ext)) return FileType.image;
    if (_textExtensions.contains(ext)) return FileType.text;
    if (_knownTextFiles.contains(baseName)) return FileType.text;
    if (ext.isEmpty) return FileType.text;
    return FileType.binary;
  }
}
