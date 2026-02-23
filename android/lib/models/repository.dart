import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Repository {
  final int id;
  final String name;
  final String fullName;
  final Owner owner;
  final bool isPrivate;
  final String? description;
  final String cloneUrl;
  final String defaultBranch;
  final int stargazersCount;
  final String updatedAt;
  final bool fork;

  const Repository({
    required this.id,
    required this.name,
    required this.fullName,
    required this.owner,
    required this.isPrivate,
    this.description,
    required this.cloneUrl,
    required this.defaultBranch,
    required this.stargazersCount,
    required this.updatedAt,
    required this.fork,
  });

  factory Repository.fromJson(Map<String, dynamic> json) => Repository(
        id: json['id'] as int,
        name: json['name'] as String,
        fullName: json['full_name'] as String,
        owner: Owner.fromJson(json['owner'] as Map<String, dynamic>),
        isPrivate: json['private'] as bool? ?? false,
        description: json['description'] as String?,
        cloneUrl: json['clone_url'] as String,
        defaultBranch: json['default_branch'] as String? ?? 'main',
        stargazersCount: json['stargazers_count'] as int? ?? 0,
        updatedAt: json['updated_at'] as String? ?? '',
        fork: json['fork'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) => other is Repository && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Future<bool> get isClonedLocally async {
    final path = await localPath;
    return Directory(path).existsSync();
  }

  Future<String> get localPath async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/repos/$fullName';
  }
}

class Owner {
  final String login;
  final String avatarUrl;

  const Owner({required this.login, required this.avatarUrl});

  factory Owner.fromJson(Map<String, dynamic> json) => Owner(
        login: json['login'] as String,
        avatarUrl: json['avatar_url'] as String? ?? '',
      );
}
