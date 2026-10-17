import 'package:flutter/material.dart';
import '../models/saved_connection.dart';
import '../services/storage_service.dart';
import '../services/search_service.dart';

class ConnectionsProvider extends ChangeNotifier {
  final StorageService _storageService;

  List<SavedConnection> _connections = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String? _selectedEventFilter;
  String? _selectedTechStackFilter;
  String? _selectedVibeFilter;

  ConnectionsProvider(this._storageService) {
    loadConnections();
  }

  List<SavedConnection> get connections => _connections;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedEventFilter => _selectedEventFilter;
  String? get selectedTechStackFilter => _selectedTechStackFilter;
  String? get selectedVibeFilter => _selectedVibeFilter;

  List<String> get uniqueEvents => SearchService.extractUniqueEvents(_connections);
  List<String> get uniqueTechStacks => SearchService.extractUniqueTechStacks(_connections);
  List<String> get uniqueVibes => SearchService.extractUniqueVibes(_connections);

  List<SearchResult> get searchResults {
    return SearchService.search(
      connections: _connections,
      query: _searchQuery,
      filterEvent: _selectedEventFilter,
      filterTechStack: _selectedTechStackFilter,
      filterVibe: _selectedVibeFilter,
    );
  }

  Future<void> loadConnections() async {
    _isLoading = true;
    notifyListeners();
    _connections = await _storageService.loadConnections();
    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setEventFilter(String? eventName) {
    _selectedEventFilter = (_selectedEventFilter == eventName) ? null : eventName;
    notifyListeners();
  }

  void setTechStackFilter(String? tech) {
    _selectedTechStackFilter = (_selectedTechStackFilter == tech) ? null : tech;
    notifyListeners();
  }

  void setVibeFilter(String? vibe) {
    _selectedVibeFilter = (_selectedVibeFilter == vibe) ? null : vibe;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedEventFilter = null;
    _selectedTechStackFilter = null;
    _selectedVibeFilter = null;
    notifyListeners();
  }

  Future<void> addConnection(SavedConnection connection) async {
    _connections.insert(0, connection);
    await _storageService.saveConnections(_connections);
    notifyListeners();
  }

  Future<void> updateConnection(SavedConnection updated) async {
    final index = _connections.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _connections[index] = updated;
      await _storageService.saveConnections(_connections);
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String connectionId) async {
    final index = _connections.indexWhere((c) => c.id == connectionId);
    if (index != -1) {
      _connections[index] = _connections[index].copyWith(
        isFavorite: !_connections[index].isFavorite,
      );
      await _storageService.saveConnections(_connections);
      notifyListeners();
    }
  }

  Future<void> deleteConnection(String connectionId) async {
    _connections.removeWhere((c) => c.id == connectionId);
    await _storageService.saveConnections(_connections);
    notifyListeners();
  }
}
