import Foundation

// MARK: - GitHub Git Data API Response Models

/// GET /repos/{owner}/{repo}/git/ref/heads/{branch}
struct GitRefResponse: Codable {
    let ref: String
    let object: GitRefObject
}

struct GitRefObject: Codable {
    let sha: String
    let type: String
}

/// GET /repos/{owner}/{repo}/git/commits/{sha}
struct GitCommitDetail: Codable {
    let sha: String
    let message: String
    let tree: GitCommitTree
    let parents: [GitCommitParent]

    struct GitCommitTree: Codable {
        let sha: String
    }

    struct GitCommitParent: Codable {
        let sha: String
    }
}

/// POST /repos/{owner}/{repo}/git/blobs
struct GitBlobResponse: Codable {
    let sha: String
    let url: String
}

/// POST /repos/{owner}/{repo}/git/trees
struct GitTreeResponse: Codable {
    let sha: String
    let tree: [GitTreeEntryResponse]
}

struct GitTreeEntryResponse: Codable {
    let path: String
    let mode: String
    let type: String
    let sha: String
    let size: Int?
}

/// POST /repos/{owner}/{repo}/git/commits
struct GitCommitResponse: Codable {
    let sha: String
    let message: String
}

// MARK: - Request Body Models

struct CreateBlobRequest: Codable {
    let content: String
    let encoding: String
}

struct CreateTreeEntry: Codable {
    let path: String
    let mode: String
    let type: String
    let sha: String?     // nil for deletions
    let content: String?  // inline content alternative

    enum CodingKeys: String, CodingKey {
        case path, mode, type, sha, content
    }

    init(path: String, mode: String = "100644", type: String = "blob", sha: String? = nil, content: String? = nil) {
        self.path = path
        self.mode = mode
        self.type = type
        self.sha = sha
        self.content = content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encode(mode, forKey: .mode)
        try container.encode(type, forKey: .type)
        // GitHub API requires "sha": null to be explicitly present for deletions
        if let sha = sha {
            try container.encode(sha, forKey: .sha)
        } else {
            try container.encodeNil(forKey: .sha)
        }
        // Only encode content when present
        if let content = content {
            try container.encode(content, forKey: .content)
        }
    }
}

struct CreateTreeRequest: Codable {
    let baseTree: String?
    let tree: [CreateTreeEntry]

    enum CodingKeys: String, CodingKey {
        case baseTree = "base_tree"
        case tree
    }
}

struct CreateCommitRequest: Codable {
    let message: String
    let tree: String
    let parents: [String]
}

struct UpdateRefRequest: Codable {
    let sha: String
    let force: Bool
}

/// GET /repos/{owner}/{repo}/contents/{path} (JSON response, not raw)
struct GitContentResponse: Codable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let content: String?
    let encoding: String?
}
