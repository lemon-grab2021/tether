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
    final rawRelationship =
        json['relationship']?.toString().toLowerCase().trim() ?? 'none';

    String normalizedRelationship;
    switch (rawRelationship) {
      case 'link':
      case 'linked':
      case 'accepted':
      case 'existing_link':
        normalizedRelationship = 'link';
        break;

      case 'outgoing_pending':
      case 'pending_outgoing':
      case 'outgoing':
      case 'sent':
        normalizedRelationship = 'outgoing_pending';
        break;

      case 'incoming_pending':
      case 'pending_incoming':
      case 'incoming':
      case 'received':
        normalizedRelationship = 'incoming_pending';
        break;

      default:
        normalizedRelationship = 'none';
    }

    return LinkSearchResult(
      user: LinkUser.fromJson(Map<String, dynamic>.from(json['user'])),
      relationship: normalizedRelationship,
      requestId: json['requestId'] != null
          ? (json['requestId'] is int
              ? json['requestId']
              : int.parse(json['requestId'].toString()))
          : null,
    );
  }
}