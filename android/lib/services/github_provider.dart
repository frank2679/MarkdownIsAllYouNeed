import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../models/repository.dart';
import '../models/git_api_models.dart';
import '../utils/constants.dart';

class GitHubProvider {
  final String token;

  const GitHubProvider({required this.token});

  Future<UserProfile> fetchUserProfile() async {
    final data = await _request('/user');
    return UserProfile.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<List<Repository>> fetchRepos({int page = 1}) async {
    final data = await _request(
      '/user/repos',
      queryParams: {
        'page': '$page',
        'per_page': '30',
        'sort': 'updated',
        'affiliation': 'owner,collaborator,organization_member',
      },
    );
    final list = jsonDecode(data) as List<dynamic>;
    return list
        .map((e) => Repository.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GitRefResponse> getRef({
    required String owner,
    required String repo,
    required String branch,
  }) async {
    final data = await _request('/repos/$owner/$repo/git/ref/heads/$branch');
    return GitRefResponse.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<GitCommitDetail> getCommit({
    required String owner,
    required String repo,
    required String sha,
  }) async {
    final data = await _request('/repos/$owner/$repo/git/commits/$sha');
    return GitCommitDetail.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<GitTreeResponse> getTree({
    required String owner,
    required String repo,
    required String treeSha,
    bool recursive = true,
  }) async {
    final data = await _request(
      '/repos/$owner/$repo/git/trees/$treeSha',
      queryParams: recursive ? {'recursive': '1'} : {},
    );
    return GitTreeResponse.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<List<int>> getFileContent({
    required String owner,
    required String repo,
    required String path,
    required String ref,
  }) async {
    final encoded = Uri.encodeComponent(path).replaceAll('%2F', '/');
    final raw = await _request(
      '/repos/$owner/$repo/contents/$encoded',
      queryParams: {'ref': ref},
      accept: 'application/vnd.github.raw+json',
      rawBytes: true,
    );
    return raw.codeUnits;
  }

  Future<List<int>> getFileContentBytes({
    required String owner,
    required String repo,
    required String path,
    required String ref,
  }) async {
    final encoded = Uri.encodeComponent(path).replaceAll('%2F', '/');
    final uri = Uri.parse(
      '${AppConstants.githubAPIBase}/repos/$owner/$repo/contents/$encoded',
    ).replace(queryParameters: {'ref': ref});

    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/vnd.github.raw+json';

    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw GitHubException.http(response.statusCode);
    }
    return response.stream.toBytes();
  }

  Future<GitBlobResponse> createBlob({
    required String owner,
    required String repo,
    required String content,
    String encoding = 'base64',
  }) async {
    final data = await _request(
      '/repos/$owner/$repo/git/blobs',
      method: 'POST',
      body: jsonEncode(CreateBlobRequest(content: content, encoding: encoding).toJson()),
    );
    return GitBlobResponse.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<GitTreeResponse> createTree({
    required String owner,
    required String repo,
    required String baseTree,
    required List<CreateTreeEntry> entries,
  }) async {
    final data = await _request(
      '/repos/$owner/$repo/git/trees',
      method: 'POST',
      body: jsonEncode(CreateTreeRequest(baseTree: baseTree, tree: entries).toJson()),
    );
    return GitTreeResponse.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<GitCommitResponse> createCommit({
    required String owner,
    required String repo,
    required String message,
    required String tree,
    required List<String> parents,
  }) async {
    final data = await _request(
      '/repos/$owner/$repo/git/commits',
      method: 'POST',
      body: jsonEncode(CreateCommitRequest(message: message, tree: tree, parents: parents).toJson()),
    );
    return GitCommitResponse.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<GitRefResponse> updateRef({
    required String owner,
    required String repo,
    required String branch,
    required String sha,
    bool force = false,
  }) async {
    final data = await _request(
      '/repos/$owner/$repo/git/refs/heads/$branch',
      method: 'PATCH',
      body: jsonEncode(UpdateRefRequest(sha: sha, force: force).toJson()),
    );
    return GitRefResponse.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  // MARK: - Internal HTTP helper

  Future<String> _request(
    String path, {
    Map<String, String>? queryParams,
    String method = 'GET',
    String? body,
    String accept = 'application/vnd.github+json',
    bool rawBytes = false,
  }) async {
    var uri = Uri.parse('${AppConstants.githubAPIBase}$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': accept,
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    final http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(uri, headers: headers, body: body);
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: body);
      default:
        response = await http.get(uri, headers: headers);
    }

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw GitHubException.http(response.statusCode);
    }

    return response.body;
  }
}

class GitHubException implements Exception {
  final String message;

  const GitHubException(this.message);
  GitHubException.http(int statusCode)
      : message = 'GitHub API error (HTTP $statusCode)';

  @override
  String toString() => 'GitHubException: $message';
}
