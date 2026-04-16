import 'link_user.dart';

class LinkModel {
  final int requestId;
  final LinkUser user;
  final DateTime? connectedAt;

  LinkModel({
    required this.requestId,
    required this.user,
    this.connectedAt,
  });

  factory LinkModel.fromJson(Map<String, dynamic> json) {
    return LinkModel(
      requestId: json['requestId'] is int
          ? json['requestId']
          : int.parse(json['requestId'].toString()),
      user: LinkUser.fromJson(Map<String, dynamic>.from(json['user'])),
      connectedAt: json['connectedAt'] != null
          ? DateTime.parse(json['connectedAt'].toString())
          : null,
    );
  }
}