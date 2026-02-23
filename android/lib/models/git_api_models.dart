// GitHub Git Data API Response Models

class GitRefResponse {
  final String ref;
  final GitRefObject object;

  const GitRefResponse({required this.ref, required this.object});

  factory GitRefResponse.fromJson(Map<String, dynamic> json) => GitRefResponse(
        ref: json['ref'] as String,
        object: GitRefObject.fromJson(json['object'] as Map<String, dynamic>),
      );
}

class GitRefObject {
  final String sha;
  final String type;

  const GitRefObject({required this.sha, required this.type});

  factory GitRefObject.fromJson(Map<String, dynamic> json) => GitRefObject(
        sha: json['sha'] as String,
        type: json['type'] as String,
      );
}

class GitCommitDetail {
  final String sha;
  final String message;
  final GitCommitTree tree;
  final List<GitCommitParent> parents;

  const GitCommitDetail({
    required this.sha,
    required this.message,
    required this.tree,
    required this.parents,
  });

  factory GitCommitDetail.fromJson(Map<String, dynamic> json) =>
      GitCommitDetail(
        sha: json['sha'] as String,
        message: json['message'] as String,
        tree: GitCommitTree.fromJson(json['tree'] as Map<String, dynamic>),
        parents: (json['parents'] as List<dynamic>)
            .map((e) => GitCommitParent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class GitCommitTree {
  final String sha;
  const GitCommitTree({required this.sha});
  factory GitCommitTree.fromJson(Map<String, dynamic> json) =>
      GitCommitTree(sha: json['sha'] as String);
}

class GitCommitParent {
  final String sha;
  const GitCommitParent({required this.sha});
  factory GitCommitParent.fromJson(Map<String, dynamic> json) =>
      GitCommitParent(sha: json['sha'] as String);
}

class GitBlobResponse {
  final String sha;
  final String url;

  const GitBlobResponse({required this.sha, required this.url});

  factory GitBlobResponse.fromJson(Map<String, dynamic> json) => GitBlobResponse(
        sha: json['sha'] as String,
        url: json['url'] as String,
      );
}

class GitTreeResponse {
  final String sha;
  final List<GitTreeEntryResponse> tree;

  const GitTreeResponse({required this.sha, required this.tree});

  factory GitTreeResponse.fromJson(Map<String, dynamic> json) => GitTreeResponse(
        sha: json['sha'] as String,
        tree: (json['tree'] as List<dynamic>)
            .map((e) => GitTreeEntryResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class GitTreeEntryResponse {
  final String path;
  final String mode;
  final String type;
  final String sha;
  final int? size;

  const GitTreeEntryResponse({
    required this.path,
    required this.mode,
    required this.type,
    required this.sha,
    this.size,
  });

  factory GitTreeEntryResponse.fromJson(Map<String, dynamic> json) =>
      GitTreeEntryResponse(
        path: json['path'] as String,
        mode: json['mode'] as String,
        type: json['type'] as String,
        sha: json['sha'] as String? ?? '',
        size: json['size'] as int?,
      );
}

class GitCommitResponse {
  final String sha;
  final String message;

  const GitCommitResponse({required this.sha, required this.message});

  factory GitCommitResponse.fromJson(Map<String, dynamic> json) =>
      GitCommitResponse(
        sha: json['sha'] as String,
        message: json['message'] as String,
      );
}

// Request Models

class CreateBlobRequest {
  final String content;
  final String encoding;

  const CreateBlobRequest({required this.content, required this.encoding});

  Map<String, dynamic> toJson() => {'content': content, 'encoding': encoding};
}

class CreateTreeEntry {
  final String path;
  final String mode;
  final String type;
  final String? sha; // null for deletions
  final String? content;

  const CreateTreeEntry({
    required this.path,
    this.mode = '100644',
    this.type = 'blob',
    this.sha,
    this.content,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'path': path,
      'mode': mode,
      'type': type,
      'sha': sha, // explicitly null for deletions
    };
    if (content != null) map['content'] = content;
    return map;
  }
}

class CreateTreeRequest {
  final String? baseTree;
  final List<CreateTreeEntry> tree;

  const CreateTreeRequest({this.baseTree, required this.tree});

  Map<String, dynamic> toJson() => {
        'base_tree': baseTree,
        'tree': tree.map((e) => e.toJson()).toList(),
      };
}

class CreateCommitRequest {
  final String message;
  final String tree;
  final List<String> parents;

  const CreateCommitRequest({
    required this.message,
    required this.tree,
    required this.parents,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'tree': tree,
        'parents': parents,
      };
}

class UpdateRefRequest {
  final String sha;
  final bool force;

  const UpdateRefRequest({required this.sha, required this.force});

  Map<String, dynamic> toJson() => {'sha': sha, 'force': force};
}
