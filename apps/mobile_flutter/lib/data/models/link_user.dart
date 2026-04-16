class LinkUser {
  final int id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  LinkUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory LinkUser.fromJson(Map<String, dynamic> json) {
    return LinkUser(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}