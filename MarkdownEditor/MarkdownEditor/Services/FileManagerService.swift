import Foundation

final class FileManagerService {
    static let shared = FileManagerService()
    private let fm = FileManager.default
    private init() {}

    /// Build a file tree from a local repo directory
    func buildFileTree(at rootURL: URL) -> [FileNode] {
        buildFileTree(at: rootURL, repoRoot: rootURL)
    }

    private func buildFileTree(at directoryURL: URL, repoRoot: URL) -> [FileNode] {
        guard let contents = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        let rootPath = repoRoot.standardizedFileURL.path
        var nodes: [FileNode] = []

        for url in contents {
            let name = url.lastPathComponent

            // Skip metadata and originals
            if name == ".repo-metadata.json" || name == ".originals" { continue }

            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let filePath = url.standardizedFileURL.path
            var relativePath = filePath
            if filePath.hasPrefix(rootPath) {
                relativePath = String(filePath.dropFirst(rootPath.count))
                if relativePath.hasPrefix("/") {
                    relativePath.removeFirst()
                }
            }

            if isDirectory {
                let children = buildFileTree(at: url, repoRoot: repoRoot)
                let node = FileNode(
                    name: name,
                    path: relativePath,
                    isDirectory: true,
                    fileType: .binary,
                    children: children
                )
                nodes.append(node)
            } else {
                let fileType = FileTypeDetector.detect(filename: name)
                let node = FileNode(
                    name: name,
                    path: relativePath,
                    isDirectory: false,
                    fileType: fileType
                )
                nodes.append(node)
            }
        }

        return nodes.sorted()
    }

    /// Build a file tree annotated with change status from a list of FileChanges.
    func buildFileTree(at rootURL: URL, changes: [FileChange]) -> [FileNode] {
        let changeMap = Dictionary(uniqueKeysWithValues: changes.map { ($0.path, $0.changeType) })
        var nodes = buildFileTree(at: rootURL)
        annotateNodes(&nodes, changeMap: changeMap)
        return nodes
    }

    /// Recursively annotate nodes with their change type.
    private func annotateNodes(_ nodes: inout [FileNode], changeMap: [String: FileChangeType]) {
        for i in nodes.indices {
            if let changeType = changeMap[nodes[i].path] {
                nodes[i].changeType = changeType
            }
            if var children = nodes[i].children {
                annotateNodes(&children, changeMap: changeMap)
                nodes[i].children = children
            }
        }
    }

    /// Read file content as string
    func readFileContent(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    /// Write file content
    func writeFileContent(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Create a new file
    func createFile(named name: String, in directoryURL: URL) throws -> URL {
        let fileURL = directoryURL.appendingPathComponent(name)
        fm.createFile(atPath: fileURL.path, contents: nil)
        return fileURL
    }

    /// Create a new directory
    func createDirectory(named name: String, in parentURL: URL) throws -> URL {
        let dirURL = parentURL.appendingPathComponent(name)
        try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }

    /// Delete a file or directory
    func delete(at url: URL) throws {
        try fm.removeItem(at: url)
    }

    /// Rename a file or directory
    func rename(at url: URL, to newName: String) throws -> URL {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fm.moveItem(at: url, to: newURL)
        return newURL
    }

    /// Get file size
    func fileSize(at url: URL) -> Int64 {
        let attributes = try? fm.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int64 ?? 0
    }

    /// Check if path is a text file that can be edited
    func isEditable(at url: URL) -> Bool {
        let fileType = FileTypeDetector.detect(filename: url.lastPathComponent)
        return fileType == .markdown || fileType == .text
    }
}
