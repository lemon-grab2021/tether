import 'link_user.dart';

class LinkSearchResult {
  final LinkUser user;
  final String relationship;
  final int? requestId;

  LinkSearchResult({
    required this.user,
    required this.relationship,
    this.requestId,
  });

  factory LinkSearchResult.fromJson(Map<String, dynamic> json) {
    return LinkSearchResult(
      user: LinkUser.fromJson(Map<String, dynamic>.from(json['user'])),
      relationship: json['relationship']?.toString() ?? 'none',
      requestId: json['requestId'] != null ? (json['requestId'] is int ? json['requestId'] : int.parse(json['requestId'].toString())) : null,
    );
  } 
}