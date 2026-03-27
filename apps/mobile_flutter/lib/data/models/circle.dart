class Circle {
  final int id;
  final String name;
  final String? description;
  final bool isPrivate;
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CircleMember>? members;
  final MessageCount? messageCount;

  Circle({
    required this.id,
    required this.name,
    this.description,
    required this.isPrivate,
    this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
    this.members,
    this.messageCount,
  });

  factory Circle.fromJson(Map<String, dynamic> json) {
    return Circle(
      id: json ['id'],
      name: json['name'],
      description: json['description'],
      isPrivate: json['isPrivate'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      //Explain
      members: json['members'] != null 
          ? (json['members'] as List)
              .map((m) => CircleMember.fromJson(m))
              .toList()
          : null, 
      messageCount: json['_count'] != null
          ? MessageCount.fromJson(json['_count']) 
          : null,   
    );
  }
}  

class CircleMember {
  final int id;
  final int userId;
  final int circleId;
  final String role;
  final DateTime joinedAt;
  final MemberUser? user;

  CircleMember ({
    required this.id,
    required this.userId,
    required this.circleId,
    required this.role,
    required this.joinedAt,
    this.user,
  });

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    return CircleMember ( 
      id: json['id'],
      userId: json['userId'],
      circleId: json['circleId'],
      role: json['role'],
      joinedAt: DateTime.parse(json['joinedAt']),
      user: json['user'] != null ? MemberUser.fromJson(json['user']) : null,
    );
  }
}

class MemberUser { 
  final int id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  MemberUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory MemberUser.fromJson(Map<String, dynamic> json) {
    return MemberUser(
      id: json['id'],
      username: json['username'],
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

class MessageCount {
  final int members;
  final int messages;

  MessageCount({required this.members, required this.messages});

  factory MessageCount.fromJson(Map<String, dynamic> json) {
    return MessageCount(
      members: json['members'] ?? 0,
      messages: json['messages'] ?? 0,
    );
  }
}

