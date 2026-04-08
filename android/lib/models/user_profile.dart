class UserProfile {
  final int id;
  final String login;
  final String avatarUrl;
  final String? name;
  final String? bio;
  final int publicRepos;
  final int privateRepos;

  const UserProfile({
    required this.id,
    required this.login,
    required this.avatarUrl,
    this.name,
    this.bio,
    required this.publicRepos,
    required this.privateRepos,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as int,
        login: json['login'] as String,
        avatarUrl: json['avatar_url'] as String,
        name: json['name'] as String?,
        bio: json['bio'] as String?,
        publicRepos: json['public_repos'] as int? ?? 0,
        privateRepos: json['total_private_repos'] as int? ?? 0,
      );
}
