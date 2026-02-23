import 'dart:io';
import '../models/file_node.dart';
import '../models/git_status.dart';

class FileManagerService {
  static final FileManagerService shared = FileManagerService._();
  FileManagerService._();

  static const _skipNames = {'.repo-metadata.json', '.originals'};

  List<FileNode> buildFileTree(String rootPath) {
    return _buildTree(Directory(rootPath), rootPath);
  }

  List<FileNode> buildFileTreeWithChanges(
    String rootPath,
    List<FileChange> changes,
  ) {
    final changeMap = {for (final c in changes) c.path: c.changeType};
    var nodes = buildFileTree(rootPath);
    _annotateNodes(nodes, changeMap);
    return nodes;
  }

  List<FileNode> _buildTree(Directory dir, String rootPath) {
    final List<FileNode> nodes = [];

    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync();
    } catch (_) {
      return nodes;
    }

    for (final entry in entries) {
      final name = entry.path.split('/').last;
      if (_skipNames.contains(name)) continue;

      final relPath = relativePath(entry.path, rootPath);

      if (entry is Directory) {
        final children = _buildTree(entry, rootPath);
        nodes.add(FileNode(
          name: name,
          path: relPath,
          isDirectory: true,
          fileType: FileType.binary,
          children: children,
        ));
      } else if (entry is File) {
        final fileType = FileTypeDetector.detect(name);
        nodes.add(FileNode(
          name: name,
          path: relPath,
          isDirectory: false,
          fileType: fileType,
        ));
      }
    }

    nodes.sort();
    return nodes;
  }

  void _annotateNodes(List<FileNode> nodes, Map<String, FileChangeType> changeMap) {
    for (final node in nodes) {
      if (changeMap.containsKey(node.path)) {
        node.changeType = changeMap[node.path];
      }
      if (node.children != null) {
        _annotateNodes(node.children!, changeMap);
      }
    }
  }

  String? readFileContent(String path) {
    try {
      return File(path).readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  void writeFileContent(String content, String path) {
    File(path).writeAsStringSync(content, flush: true);
  }

  String createFile(String name, String directoryPath) {
    final filePath = '$directoryPath/$name';
    File(filePath).createSync(recursive: true);
    return filePath;
  }

  String createDirectory(String name, String parentPath) {
    final dirPath = '$parentPath/$name';
    Directory(dirPath).createSync(recursive: true);
    return dirPath;
  }

  void delete(String path) {
    final entity = FileSystemEntity.typeSync(path) == FileSystemEntityType.directory
        ? Directory(path)
        : File(path) as FileSystemEntity;
    entity.deleteSync(recursive: true);
  }

  void move(String sourcePath, String destPath) {
    FileSystemEntity.typeSync(sourcePath) == FileSystemEntityType.directory
        ? Directory(sourcePath).renameSync(destPath)
        : File(sourcePath).renameSync(destPath);
  }

  String rename(String path, String newName) {
    final parent = path.substring(0, path.lastIndexOf('/'));
    final newPath = '$parent/$newName';
    move(path, newPath);
    return newPath;
  }

  int fileSize(String path) {
    try {
      return File(path).statSync().size;
    } catch (_) {
      return 0;
    }
  }

  bool isEditable(String filename) {
    final type = FileTypeDetector.detect(filename);
    return type == FileType.markdown || type == FileType.text;
  }

  static String relativePath(String fullPath, String rootPath) {
    if (fullPath.startsWith(rootPath)) {
      var rel = fullPath.substring(rootPath.length);
      if (rel.startsWith('/')) rel = rel.substring(1);
      return rel;
    }
    return fullPath;
  }

  // Directory size helper
  int directorySize(String path) {
    try {
      int size = 0;
      Directory(path)
          .listSync(recursive: true)
          .whereType<File>()
          .forEach((f) => size += f.statSync().size);
      return size;
    } catch (_) {
      return 0;
    }
  }
}
