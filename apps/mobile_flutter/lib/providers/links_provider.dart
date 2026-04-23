import 'package:flutter/material.dart';
import '../data/models/link.dart';
import '../data/models/link_request.dart';
import '../data/models/link_search_result.dart';
import '../data/services/auth_service.dart';
import '../data/services/links_service.dart';

class LinksProvider extends ChangeNotifier {
  final LinksService _linksService = LinksService();
  final AuthService _authService = AuthService();

  List<LinkSearchResult> _searchResults = [];
  List<LinkRequestModel> _incomingRequests = [];
  List<LinkRequestModel> _outgoingRequests = [];
  List<LinkModel> _links = [];

  bool _isLoading = false;
  String? _error;
  String _lastSearchQuery = '';
  bool _disposed = false;

  List<LinkSearchResult> get searchResults => _searchResults;
  List<LinkRequestModel> get incomingRequests => _incomingRequests;
  List<LinkRequestModel> get outgoingRequests => _outgoingRequests;
  List<LinkModel> get links => _links;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<String> _getToken() async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');
    return token;
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> searchUsers(String query) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      _lastSearchQuery = '';
      _searchResults = [];
      _error = null;
      _isLoading = false;
      _safeNotify();
      return;
    }

    _lastSearchQuery = trimmed;
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final token = await _getToken();
      final results = await _linksService.searchUsers(
        token: token,
        query: trimmed,
      );

      if (_disposed) return;

      _searchResults = results;
      _error = null;
    } catch (e) {
      if (_disposed) return;

      _searchResults = [];
      _error = e.toString();
    } finally {
      if (_disposed) return;

      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> loadRequests() async {
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final token = await _getToken();
      final incoming = await _linksService.getIncomingRequests(token: token);
      final outgoing = await _linksService.getOutgoingRequests(token: token);

      if (_disposed) return;

      _incomingRequests = incoming;
      _outgoingRequests = outgoing;
      _error = null;
    } catch (e) {
      if (_disposed) return;
      _error = e.toString();
    } finally {
      if (_disposed) return;
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> loadLinks() async {
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final token = await _getToken();
      final links = await _linksService.getLinks(token: token);

      if (_disposed) return;

      _links = links;
      _error = null;
    } catch (e) {
      if (_disposed) return;
      _error = e.toString();
    } finally {
      if (_disposed) return;
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> sendLinkRequest(int receiverId) async {
    final token = await _getToken();
    await _linksService.sendRequest(token: token, receiverId: receiverId);
    await loadRequests();
    await refreshSearchResultsIfNeeded();
  }

  Future<void> respondToRequest(int requestId, String action) async {
    final token = await _getToken();
    await _linksService.respondToRequest(
      token: token,
      requestId: requestId,
      action: action,
    );
    await loadRequests();
    await loadLinks();
    await refreshSearchResultsIfNeeded();
  }

  Future<void> removeLink(int otherUserId) async {
    final token = await _getToken();
    await _linksService.removeLink(token: token, otherUserId: otherUserId);
    await loadLinks();
    await refreshSearchResultsIfNeeded();
  }

  Future<void> refreshSearchResultsIfNeeded() async {
    if (_lastSearchQuery.isEmpty) return;

    try {
      final token = await _getToken();
      final results = await _linksService.searchUsers(
        token: token,
        query: _lastSearchQuery,
      );

      if (_disposed) return;

      _searchResults = results;
      _error = null;
      _safeNotify();
    } catch (e) {
      if (_disposed) return;

      _error = e.toString();
      _safeNotify();
    }
  }
}