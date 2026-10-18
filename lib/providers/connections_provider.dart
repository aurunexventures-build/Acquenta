import '../services/reminder_notifications.dart';
import '../services/duplicate_service.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/interaction.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'cards_provider.dart';
import 'package:flutter/material.dart';
import '../models/saved_connection.dart';
import '../services/storage_service.dart';
import '../services/search_service.dart';

class ConnectionsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final ReminderNotifications reminders;
  String get notificationStatus => reminders.status;
  bool get notificationsEnabled => reminders.enabled;

  final SyncService _syncService;
  AuthService? _auth;
  Timer? _searchTimer;
  Timer? _syncTimer;
  CardsProvider? _cards;
  bool _syncRequested = false;
  bool _accountDeleting = false;
  Completer<void>? _syncIdle;
  bool _disposed = false;
  String syncStatus = '';
  int _searchGeneration = 0;
  List<Map<String, dynamic>> _cloudMatches = [];
  bool aiSearching = false;
  bool syncing = false;
  String aiStatus = 'Local search works offline. Sign in for AI recall.';
  List<SavedConnection> _connections = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String? _selectedEventFilter;
  String? _selectedTechStackFilter;
  String? _selectedVibeFilter;

  ConnectionsProvider(
    this._storageService, {
    SyncService? syncService,
    ReminderNotifications? reminders,
  }) : reminders = reminders ?? ReminderNotifications(),
       _syncService = syncService ?? SyncService() {
    loadConnections();
  }

  List<SavedConnection> get connections => _connections;
  bool get isLoading => _isLoading;
  String get walletScope => _storageService.scope;
  String get searchQuery => _searchQuery;
  String? get selectedEventFilter => _selectedEventFilter;
  String? get selectedTechStackFilter => _selectedTechStackFilter;
  String? get selectedVibeFilter => _selectedVibeFilter;

  List<String> get uniqueEvents =>
      SearchService.extractUniqueEvents(_connections);
  List<String> get uniqueTechStacks =>
      SearchService.extractUniqueTechStacks(_connections);
  List<String> get uniqueVibes =>
      SearchService.extractUniqueVibes(_connections);

  List<SearchResult> get searchResults {
    final local = SearchService.search(
      connections: _connections,
      query: _searchQuery,
      filterEvent: _selectedEventFilter,
      filterTechStack: _selectedTechStackFilter,
      filterVibe: _selectedVibeFilter,
    );
    if (_cloudMatches.isEmpty ||
        SearchService.queryTerms(_searchQuery).isEmpty) {
      return local;
    }
    final candidates = {
      for (final result in local) result.connection.id: result,
    };
    final ranks = <String, double>{};
    for (var i = 0; i < local.length; i++) {
      ranks[local[i].connection.id] = 1 / (60 + i + 1);
    }
    for (var i = 0; i < _cloudMatches.length; i++) {
      final match = _cloudMatches[i];
      final id = (match['connection'] as Map)['id'];
      final current = _connections.where((c) => c.id == id).firstOrNull;
      if (current == null ||
          !SearchService.supportsIntent(current, _searchQuery)) {
        continue;
      }
      final filtered = SearchService.search(
        connections: [current],
        query: '',
        filterEvent: _selectedEventFilter,
        filterTechStack: _selectedTechStackFilter,
        filterVibe: _selectedVibeFilter,
      );
      if (filtered.isEmpty) continue;
      final previous = candidates[current.id];
      if (previous == null && (match['score'] as num).toDouble() < .70) {
        continue;
      }
      candidates[current.id] = SearchResult(
        connection: current,
        score: previous?.score ?? (match['score'] as num).toDouble() * 100,
        matchReasons: [...?previous?.matchReasons, match['reason'] as String],
        cognitiveReason: previous?.cognitiveReason ?? '',
        activatedDomain: previous?.activatedDomain ?? '',
      );
      ranks[current.id] = (ranks[current.id] ?? 0) + 1 / (60 + i + 1);
    }
    final results = candidates.values.toList()
      ..sort((a, b) {
        final direct = SearchService.matchedTermCount(
          b.connection,
          _searchQuery,
        ).compareTo(SearchService.matchedTermCount(a.connection, _searchQuery));
        if (direct != 0) return direct;
        final rank = (ranks[b.connection.id] ?? 0).compareTo(
          ranks[a.connection.id] ?? 0,
        );
        return rank != 0
            ? rank
            : b.connection.savedAt.compareTo(a.connection.savedAt);
      });
    return results;
  }

  void bindAuth(AuthService auth, {CardsProvider? cards}) {
    _cards = cards ?? _cards;
    if (_cards != null) _cards!.onLocalChange = syncSoon;
    _auth = auth;
    _invalidateSearch();
    if (_searchQuery.trim().isNotEmpty) _scheduleAi();
    syncSoon();
  }

  void clearForAccountSwitch() {
    _syncTimer?.cancel();
    _syncRequested = false;
    syncStatus = '';
    _invalidateSearch();
    _connections = [];
    unawaited(reminders.refresh(_auth?.currentUser?.uid ?? 'guest', []));
    _searchQuery = '';
    _invalidateSearch();
    _selectedEventFilter = null;
    _selectedTechStackFilter = null;
    _selectedVibeFilter = null;
    _isLoading = true;
    notifyListeners();
  }

  void _invalidateSearch() {
    _searchTimer?.cancel();
    _searchGeneration++;
    _cloudMatches = [];
    aiSearching = false;
  }

  void _scheduleAi() {
    final auth = _auth;
    if (auth == null || !auth.isAuthenticated) {
      aiStatus = 'Local search. Sign in through Cloud Sync for AI recall.';
      return;
    }
    final query = _searchQuery.trim();
    if (query.length < 3 || SearchService.queryTerms(query).isEmpty) {
      aiStatus = 'Local search';
      return;
    }
    final generation = _searchGeneration;
    final scope = _storageService.scope;
    aiStatus = 'Searching your saved cues…';
    aiSearching = true;
    _searchTimer = Timer(const Duration(milliseconds: 700), () async {
      try {
        final data = await _syncService.semanticSearch(query, auth);
        if (generation != _searchGeneration || scope != _storageService.scope) {
          return;
        }
        _cloudMatches = (data['matches'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        aiStatus = data['indexed'] == true
            ? 'AI + local recall. Sync new cues to include them.'
            : 'AI + local recall. Some cues are waiting to be indexed.';
      } catch (_) {
        if (generation != _searchGeneration || scope != _storageService.scope) {
          return;
        }
        aiStatus = 'AI unavailable. Showing local matches.';
      }
      if (generation == _searchGeneration) {
        aiSearching = false;
        notifyListeners();
      }
    });
  }

  Future<void> suspendForAccountDeletion() async {
    _accountDeleting = true;
    _syncTimer?.cancel();
    _syncRequested = false;
    _invalidateSearch();
    await _syncIdle?.future;
    await reminders.refresh('guest', []);
  }

  void resumeAfterAccountDeletionAttempt() {
    _accountDeleting = false;
  }

  void syncSoon() {
    if (_disposed || _accountDeleting) return;
    if (_auth?.isAuthenticated != true ||
        _cards == null ||
        _storageService.scope != _auth?.currentUser?.uid) {
      return;
    }
    _syncRequested = true;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () async {
      if (syncing || _auth?.isAuthenticated != true || _cards == null) return;
      _syncRequested = false;
      final result = await syncWallet(_auth!, _cards!);
      if (_disposed) return;
      syncStatus = result.message;
      notifyListeners();
    });
  }

  Future<SyncResult> syncWallet(AuthService auth, CardsProvider cards) async {
    if (_accountDeleting || syncing) {
      return const SyncResult(
        success: false,
        message: 'A sync is already running.',
      );
    }
    if (!auth.isAuthenticated) {
      return const SyncResult(
        success: false,
        message: 'Sign in through Cloud Sync first.',
      );
    }
    final scope = _storageService.scope;
    final uid = auth.currentUser?.uid;
    syncing = true;
    _syncIdle = Completer<void>();
    _syncRequested = false;
    notifyListeners();
    try {
      final result = await _syncService.sync(
        connections: List.of(_connections),
        cards: List.of(cards.cards),
        deleted: _storageService.loadDeletions(),
        auth: auth,
      );
      if (_disposed ||
          _accountDeleting ||
          scope != _storageService.scope ||
          uid != auth.currentUser?.uid) {
        return const SyncResult(
          success: false,
          message: 'Account changed. Sync cancelled.',
        );
      }
      if (result.accountDeleted && uid != null) {
        await _storageService.deleteAccountData(uid);
        await reminders.refresh('guest', []);
        cards.clearForAccountSwitch();
        clearForAccountSwitch();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await auth.signOut();
        return result;
      }
      if (result.success) {
        final merged = {
          for (final connection in _connections) connection.id: connection,
        };
        for (final remote in result.connections) {
          if (!merged.containsKey(remote.id) ||
              remote.updatedAt.isAfter(merged[remote.id]!.updatedAt)) {
            merged[remote.id] = remote;
          } else if (remote.updatedAt.isAtSameMomentAs(
                merged[remote.id]!.updatedAt,
              ) &&
              merged[remote.id]!.avatarUrl.startsWith('data:')) {
            merged[remote.id] = merged[remote.id]!.copyWith(
              avatarUrl: remote.avatarUrl,
            );
          }
        }
        final deletions = <String, Map<String, dynamic>>{};
        for (final item in [
          ..._storageService.loadDeletions(),
          ...result.deleted,
        ]) {
          final key = '${item['kind']}:${item['id']}';
          if (!deletions.containsKey(key) ||
              DateTime.parse(
                item['updatedAt'],
              ).isAfter(DateTime.parse(deletions[key]!['updatedAt']))) {
            deletions[key] = item;
          }
        }
        for (final item in deletions.values.where(
          (e) => e['kind'] == 'connection',
        )) {
          final current = merged[item['id']];
          if (current != null &&
              !current.updatedAt.isAfter(DateTime.parse(item['updatedAt']))) {
            merged.remove(item['id']);
          }
        }
        _connections = merged.values.toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
        await _storageService.saveConnections(_connections);
        if (scope != _storageService.scope) return result;
        await _storageService.saveDeletions(deletions.values.toList());
        if (scope != _storageService.scope) return result;
        await cards.mergeCloud(result.cards, deletions.values.toList());
        unawaited(refreshReminders());
        _invalidateSearch();
        _scheduleAi();
      }
      return result;
    } finally {
      syncing = false;
      _syncIdle?.complete();
      _syncIdle = null;
      if (!_disposed) {
        if (_syncRequested) syncSoon();
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    _syncTimer?.cancel();
    if (_cards != null) _cards!.onLocalChange = null;
    _syncService.close();
    super.dispose();
  }

  Future<void> loadConnections() async {
    _isLoading = true;
    notifyListeners();
    final scope = _storageService.scope;
    final connections = await _storageService.loadConnections();
    if (scope != _storageService.scope) return;
    _connections = connections;
    unawaited(refreshReminders());
    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _invalidateSearch();
    _scheduleAi();
    notifyListeners();
  }

  void setEventFilter(String? eventName) {
    _selectedEventFilter = (_selectedEventFilter == eventName)
        ? null
        : eventName;
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
    _invalidateSearch();
    _selectedEventFilter = null;
    _selectedTechStackFilter = null;
    _selectedVibeFilter = null;
    notifyListeners();
  }

  Future<void> addConnection(SavedConnection connection) async {
    final existing = _connections
        .where((c) => c.id == connection.id)
        .firstOrNull;
    if (existing != null) {
      return; // Scanning twice never duplicates or erases private cues.
    }
    _connections.insert(
      0,
      connection.copyWith(
        updatedAt: _storageService.versionFor(
          'connection',
          connection.id,
          connection.updatedAt,
        ),
      ),
    );
    await _storageService.saveConnections(_connections);
    syncSoon();
    unawaited(refreshReminders());
    notifyListeners();
  }

  Future<void> updateConnection(
    SavedConnection updated, {
    DateTime? expectedVersion,
  }) async {
    final index = _connections.indexWhere((c) => c.id == updated.id);
    if (index == -1) {
      throw StateError('This connection is no longer available.');
    }
    if (index != -1) {
      final previous = _connections[index];
      if (expectedVersion != null &&
          !previous.updatedAt.isAtSameMomentAs(expectedVersion)) {
        throw StateError('This connection changed. Reopen it before saving.');
      }
      final history = {
        for (final item in previous.interactions) item.id: item,
        for (final item in updated.interactions) item.id: item,
      };
      final oldMemory = [
        previous.rawCue,
        previous.eventContext.notes,
        ...previous.cueConversation.map(
          (e) => "${e['question']}: ${e['answer']}",
        ),
      ].where((s) => s.trim().isNotEmpty).join('\n\n');
      final memoryChanged =
          previous.rawCue != updated.rawCue ||
          previous.eventContext.notes != updated.eventContext.notes ||
          previous.cueConversation.toString() !=
              updated.cueConversation.toString();
      if (memoryChanged && oldMemory.isNotEmpty) {
        final id = const Uuid().v4();
        history[id] = Interaction(
          id: id,
          at: previous.updatedAt,
          text: oldMemory,
          kind: 'cue',
        );
      }
      if (history.length > 100 ||
          utf8
                  .encode(
                    jsonEncode(history.values.map((e) => e.toJson()).toList()),
                  )
                  .length >
              200000) {
        throw StateError(
          'History is full (100 entries or 200 KB). Existing memories were kept.',
        );
      }
      _connections[index] = updated.copyWith(
        interactions: history.values.toList(),
        updatedAt: _storageService.versionFor(
          'connection',
          updated.id,
          _connections[index].updatedAt,
        ),
      );
      await _storageService.saveConnections(_connections);
      syncSoon();
      unawaited(refreshReminders());
      notifyListeners();
    }
  }

  Future<void> refreshReminders() async {
    await reminders.refresh(walletScope, _connections);
    if (!_disposed) notifyListeners();
  }

  Future<void> enableNotifications(bool enabled) async {
    await reminders.setEnabled(enabled, walletScope, _connections);
    if (!_disposed) notifyListeners();
  }

  Future<void> mergeIncoming(
    SavedConnection keep,
    SavedConnection incoming,
  ) async {
    final current = _connections.where((c) => c.id == keep.id).firstOrNull;
    if (current == null ||
        !current.updatedAt.isAtSameMomentAs(keep.updatedAt)) {
      throw StateError('Contact changed. Review again.');
    }
    await updateConnection(
      DuplicateService.merge(current, incoming),
      expectedVersion: keep.updatedAt,
    );
  }

  Future<void> mergeConnections(
    SavedConnection keep,
    SavedConnection source,
  ) async {
    final scope = walletScope;
    final current = _connections.where((c) => c.id == keep.id).firstOrNull;
    final other = _connections.where((c) => c.id == source.id).firstOrNull;
    if (current == null ||
        other == null ||
        keep.id == source.id ||
        !current.updatedAt.isAtSameMomentAs(keep.updatedAt) ||
        !other.updatedAt.isAtSameMomentAs(source.updatedAt)) {
      throw StateError('Contacts changed. Review them again.');
    }
    await updateConnection(
      DuplicateService.merge(current, other),
      expectedVersion: keep.updatedAt,
    );
    if (scope != walletScope) throw StateError('Account changed.');
    final latest = _connections.where((c) => c.id == source.id).firstOrNull;
    if (latest == null ||
        !latest.updatedAt.isAtSameMomentAs(source.updatedAt)) {
      throw StateError('Source changed during merge. Both contacts were kept.');
    }
    await deleteConnection(source.id);
  }

  Future<void> addInteraction(String id, String text) async {
    final value = text.trim();
    if (value.isEmpty || value.length > 2000) {
      throw ArgumentError('Enter a note of up to 2,000 characters.');
    }
    final current = _connections.where((c) => c.id == id).firstOrNull;
    if (current == null) {
      throw StateError('This connection is no longer available.');
    }
    await updateConnection(
      current.copyWith(
        interactions: [
          ...current.interactions,
          Interaction(id: const Uuid().v4(), at: DateTime.now(), text: value),
        ],
      ),
    );
  }

  List<SavedConnection> get completedFollowUps =>
      _connections
          .where((c) => c.followUpAt != null && c.followUpCompleted)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> reopenFollowUp(String id) async {
    final current = _connections.where((c) => c.id == id).firstOrNull;
    if (current == null || current.followUpAt == null) return;
    await updateConnection(current.copyWith(followUpCompleted: false));
  }

  List<SavedConnection> get pendingFollowUps =>
      _connections
          .where((c) => c.followUpAt != null && !c.followUpCompleted)
          .toList()
        ..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!));

  Future<void> setFollowUp(String id, DateTime due, String note) async {
    if (!due.isAfter(DateTime.now())) {
      throw ArgumentError('Choose a future date and time.');
    }
    final current = _connections.where((c) => c.id == id).firstOrNull;
    if (current == null) return;
    await updateConnection(
      current.copyWith(
        followUpAt: due,
        followUpNote: note.trim(),
        followUpCompleted: false,
      ),
    );
  }

  Future<void> completeFollowUp(String id) async {
    final current = _connections.where((c) => c.id == id).firstOrNull;
    if (current == null || current.followUpAt == null) return;
    await updateConnection(current.copyWith(followUpCompleted: true));
  }

  Future<void> removeFollowUp(String id) async {
    final current = _connections.where((c) => c.id == id).firstOrNull;
    if (current == null) return;
    await updateConnection(current.copyWith(clearFollowUp: true));
  }

  Future<void> toggleFavorite(String connectionId) async {
    final index = _connections.indexWhere((c) => c.id == connectionId);
    if (index != -1) {
      _connections[index] = _connections[index].copyWith(
        isFavorite: !_connections[index].isFavorite,
        updatedAt: _storageService.versionFor(
          'connection',
          connectionId,
          _connections[index].updatedAt,
        ),
      );
      await _storageService.saveConnections(_connections);
      syncSoon();
      unawaited(refreshReminders());
      notifyListeners();
    }
  }

  Future<void> deleteConnection(String connectionId) async {
    await _storageService.markDeleted(
      'connection',
      connectionId,
      _storageService.versionFor(
        'connection',
        connectionId,
        _connections.where((c) => c.id == connectionId).firstOrNull?.updatedAt,
      ),
    );
    _connections.removeWhere((c) => c.id == connectionId);
    await _storageService.saveConnections(_connections);
    syncSoon();
    unawaited(refreshReminders());
    notifyListeners();
  }
}
