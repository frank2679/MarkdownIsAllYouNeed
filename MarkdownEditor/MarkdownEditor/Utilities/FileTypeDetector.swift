import Foundation

enum FileTypeDetector {
    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    private static let textExtensions: Set<String> = [
        "txt", "swift", "js", "ts", "json", "xml", "html", "css", "yml", "yaml",
        "toml", "ini", "cfg", "conf", "sh", "bash", "zsh", "py", "rb", "go",
        "rs", "c", "cpp", "h", "hpp", "java", "kt", "m", "mm", "r", "sql",
        "graphql", "proto", "makefile", "dockerfile", "gitignore", "gitattributes",
        "editorconfig", "env", "lock", "log", "csv", "tsv",
    ]

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "svg", "webp", "ico", "heic", "heif", "tiff",
    ]

    static func detect(filename: String) -> FileType {
        let ext = (filename as NSString).pathExtension.lowercased()
        let name = (filename as NSString).lastPathComponent.lowercased()

        if markdownExtensions.contains(ext) { return .markdown }
        if imageExtensions.contains(ext) { return .image }
        if ext == "pdf" { return .pdf }
        if textExtensions.contains(ext) { return .text }

        // Files without extensions that are typically text
        let knownTextFiles: Set<String> = [
            "readme", "license", "makefile", "dockerfile", "gemfile",
            "rakefile", "podfile", "cartfile", ".gitignore", ".gitattributes",
            ".editorconfig", ".env",
        ]
        if knownTextFiles.contains(name) { return .text }

        if ext.isEmpty { return .text }
        return .binary
    }
}
