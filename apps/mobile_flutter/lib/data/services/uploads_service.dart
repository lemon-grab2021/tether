import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class UploadedMediaResult {
  final int uploadId;
  final String fileUrl;
  final String objectKey;
  final String mimeType;

  const UploadedMediaResult({
    required this.uploadId,
    required this.fileUrl,
    required this.objectKey,
    required this.mimeType,
  });
}

class UploadsService {
  final AuthService _authService = AuthService();

  Future<UploadedMediaResult> uploadMedia({
    required String filename,
    required String mimeType,
    required int fileSize,
    required Uint8List bytes,
  }) async {
    final token = await _authService.getAccessToken();

    if (token == null) {
      throw Exception('No access token found');
    }

    final requestUploadResponse = await http.post(
      Uri.parse(ApiConstants.uploadRequest),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'filename': filename,
        'mimeType': mimeType,
        'fileSize': fileSize,
      }),
    );

    if (requestUploadResponse.statusCode != 200 &&
        requestUploadResponse.statusCode != 201) {
      throw Exception(
        'Failed to request upload URL: ${requestUploadResponse.body}',
      );
    }

    final requestData = jsonDecode(requestUploadResponse.body);

    final int uploadId = requestData['uploadId'];
    final String uploadUrl = requestData['uploadUrl'];
    final String fileUrl = requestData['fileUrl'];
    final String key = requestData['key'];
    final String returnedMimeType = requestData['mimeType'];

    final putResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Type': mimeType,
      },
      body: bytes,
    );

    if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
      throw Exception('Failed to upload file: ${putResponse.body}');
    }

    final completeResponse = await http.patch(
      Uri.parse(ApiConstants.uploadComplete(uploadId)),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (completeResponse.statusCode != 200 &&
        completeResponse.statusCode != 201) {
      throw Exception('Failed to complete upload: ${completeResponse.body}');
    }

    final completeData = jsonDecode(completeResponse.body);

    return UploadedMediaResult(
      uploadId: uploadId,
      fileUrl: completeData['fileUrl'] ?? fileUrl,
      objectKey: completeData['objectKey'] ?? key,
      mimeType: completeData['mimeType'] ?? returnedMimeType,
    );
  }
}