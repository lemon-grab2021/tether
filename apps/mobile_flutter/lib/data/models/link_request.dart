import 'link_user.dart';

class LinkRequestModel {
  final int id;
  final LinkUser? sender;
  final LinkUser? receiver;
  final String status;

  LinkRequestModel({
    required this.id,
    this.sender,
    this.receiver,
    required this.status,
  });

  factory LinkRequestModel.fromJson(Map<String, dynamic> json) {
    return LinkRequestModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      sender: json['sender'] != null
          ? LinkUser.fromJson(Map<String, dynamic>.from(json['sender']))
          : null,
      receiver: json['receiver'] != null
          ? LinkUser.fromJson(Map<String, dynamic>.from(json['receiver']))
          : null,
      status: json['status']?.toString() ?? 'PENDING',
    );
  }
}