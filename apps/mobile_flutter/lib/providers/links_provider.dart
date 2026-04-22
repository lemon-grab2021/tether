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

  List<LinkSearchResult> get searchResults => _searchResults;
  List<LinkRequestModel> get incomingRequests => _incomingRequests;
  List<LinkRequestModel> get outgoingRequests => _outgoingRequests;
  List<LinkModel> get links => _links;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String _lastSearchQuery = '';

  Future<String> _getToken() async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');
    return token;
  }

  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _lastSearchQuery = query.trim();

    if (_lastSearchQuery.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getToken();
      _searchResults = await _linksService.searchUsers(
        token: token,
        query: query.trim(),
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getToken();
      _incomingRequests = await _linksService.getIncomingRequests(token: token);
      _outgoingRequests = await _linksService.getOutgoingRequests(token: token);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLinks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getToken();
      _links = await _linksService.getLinks(token: token);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
      _searchResults = await _linksService.searchUsers(
        token: token,
        query: _lastSearchQuery,
      );
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
