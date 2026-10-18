import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/voice_magic_bar.dart';
import '../services/search_service.dart';
import '../widgets/visiting_card_deck.dart';
import '../services/sync_service.dart';
import '../providers/connections_provider.dart';
import '../providers/cards_provider.dart';
import '../services/auth_service.dart';
import '../widgets/connection_memory_button.dart';
import '../widgets/recall_network.dart';
import '../widgets/recall_wireframe.dart';
import '../widgets/recall_activity.dart';
import 'connection_detail_screen.dart';

const _ink = Color(0xFF202128);
const _purple = Color(0xFF6554C0);
const _paper = Color(0xFFF6F5F1);

class SmartSearchScreen extends StatefulWidget {
  final SyncService Function()? serviceFactory;
  const SmartSearchScreen({super.key, this.serviceFactory});
  @override
  State<SmartSearchScreen> createState() => _SmartSearchScreenState();
}

class _SmartSearchScreenState extends State<SmartSearchScreen>
    with WidgetsBindingObserver {
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  final _query = TextEditingController();
  Timer? _debounce;
  bool _typing = false, _organising = false;
  bool _showThinking = true;
  static const _thinkingKey = 'recall_show_matching_flow_v2';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _query.text = context.read<ConnectionsProvider>().searchQuery;
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _showThinking = prefs.getBool(_thinkingKey) ?? true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    context.read<ConnectionsProvider>().setSearchQuery(value);
    setState(() => _typing = value.trim().isNotEmpty);
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _typing = false);
    });
  }

  Future<void> _organiseQuery() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    final original = _query.text.trim();
    final auth = context.read<AuthService?>();
    if (original.isEmpty || auth == null || !auth.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            persist: false,
            duration: Duration(seconds: 3),
            content: Text(
              'Type or speak a detail. Sign in to tidy it with AI.',
            ),
          ),
        );
      }
      return;
    }
    final uid = auth.currentUser?.uid;
    setState(() => _organising = true);
    final service = widget.serviceFactory?.call() ?? SyncService();
    try {
      final result = await service.request('/api/v1/text/organise', {
        'text': original,
        'purpose': 'search',
      }, auth);
      if (!mounted ||
          auth.currentUser?.uid != uid ||
          _query.text.trim() != original) {
        return;
      }
      final text = result['text'];
      if (text is! String || text.trim().isEmpty) throw const FormatException();
      _query.text = text;
      _search(text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 3),
          content: const Text('Search wording tidied.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (mounted) {
                _query.text = original;
                _search(original);
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            persist: false,
            duration: Duration(seconds: 3),
            content: Text('AI unavailable. Your original search still works.'),
          ),
        );
      }
    } finally {
      service.close();
      if (mounted) setState(() => _organising = false);
    }
  }

  Future<void> _filters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final p = context.watch<ConnectionsProvider>();
          Widget options(
            String title,
            List<String> values,
            String? selected,
            ValueChanged<String?> select,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: values
                    .map(
                      (v) => FilterChip(
                        label: Text(v),
                        selected: v == selected,
                        onSelected: (_) {
                          select(v);
                          update(() {});
                        },
                        labelStyle: const TextStyle(color: _ink, fontSize: 12),
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFFE6E0F5),
                        checkmarkColor: _purple,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
          );
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Narrow it down',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: _ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  options(
                    'Event',
                    p.connections
                        .map((c) => c.eventContext.eventName)
                        .where((e) => e.isNotEmpty)
                        .toSet()
                        .toList(),
                    p.selectedEventFilter,
                    p.setEventFilter,
                  ),
                  options(
                    'Skills',
                    p.connections.expand((c) => c.techStack).toSet().toList(),
                    p.selectedTechStackFilter,
                    p.setTechStackFilter,
                  ),
                  options(
                    'Vibe',
                    p.connections.expand((c) => c.vibeTags).toSet().toList(),
                    p.selectedVibeFilter,
                    p.setVibeFilter,
                  ),
                  TextButton(
                    onPressed: () {
                      _debounce?.cancel();
                      p.clearFilters();
                      _query.clear();
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Clear filters',
                      style: TextStyle(color: _purple),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMatchEvidence(SearchResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why ${result.connection.fullName}?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final reason in result.matchReasons.toSet())
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MatchedEvidence(text: reason, query: _query.text),
                ),
              if (result.cognitiveReason.isNotEmpty)
                MatchedEvidence(
                  text: 'Related concept: ${result.cognitiveReason}',
                  query: _query.text,
                ),
              const SizedBox(height: 12),
              const Text(
                'Matches use your saved roles, skills, meeting details and notes.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  WalletEntry _resultEntry(SearchResult result, int index) {
    final summary = result.matchReasons.isNotEmpty
        ? result.matchReasons.first
        : result.cognitiveReason.isNotEmpty
        ? 'Related concept: ${result.cognitiveReason}'
        : 'Related to your search; review this person’s saved details.';
    return WalletEntry.person(
      result.connection,
      index: index,
      onOpen: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ConnectionDetailScreen(connectionId: result.connection.id),
        ),
      ),
      trailing: ConnectionMemoryButton(connection: result.connection),
      matchNote: Tooltip(
        message: summary,
        child: Material(
          color: const Color(0xFFE8E3FA),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showMatchEvidence(result),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: _purple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _ink, fontSize: 11),
                    ),
                  ),
                  const Icon(Icons.info_outline, size: 15, color: _purple),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConnectionsProvider>();
    final busy = _typing || p.aiSearching;
    final active =
        p.searchQuery.trim().isNotEmpty ||
        p.selectedEventFilter != null ||
        p.selectedTechStackFilter != null ||
        p.selectedVibeFilter != null;
    final results = p.searchResults;
    final keyboard = View.of(context).viewInsets.bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: Scaffold.maybeOf(context) == null,
      backgroundColor: _paper,
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 760;
          final input = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!keyboard) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Smart recall',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.8,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: p.aiStatus,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9E5F2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          p.aiSearching
                              ? 'AI recall'
                              : p.aiStatus.startsWith('AI +')
                              ? 'AI + local'
                              : 'Local recall',
                          style: const TextStyle(color: _purple, fontSize: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: busy ? 'Searching memories' : 'Recall filters',
                      onPressed: _filters,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          busy ? Icons.public_rounded : Icons.settings_outlined,
                          key: ValueKey(busy),
                          color: _purple,
                          size: 22,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sync memories',
                      onPressed: p.syncing
                          ? null
                          : () async {
                              final result = await p.syncWallet(
                                context.read<AuthService>(),
                                context.read<CardsProvider>(),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    persist: false,
                                    duration: const Duration(seconds: 3),
                                    content: Text(result.message),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(
                        Icons.sync_rounded,
                        color: _purple,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _query,
                style: const TextStyle(color: _ink, fontSize: 15),
                scrollPadding: const EdgeInsets.only(bottom: 96),
                textInputAction: TextInputAction.search,
                onChanged: _search,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  p.setSearchQuery(v);
                  setState(() => _typing = false);
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  hintText: 'Who are you trying to remember?',
                  hintStyle: const TextStyle(color: Color(0xFF918999)),
                  prefixIcon: const Icon(Icons.search_rounded, color: _purple),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_query.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _query.clear();
                            _search('');
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: _purple,
                          ),
                        ),
                    ],
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE4DFEC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE4DFEC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _purple, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              VoiceMagicBar(
                controller: _query,
                onMagic: _organiseQuery,
                busy: _organising,
                onChanged: _search,
                compact: true,
                trailing: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 44),
                    textStyle: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(fontSize: 11),
                  ),
                  onPressed: () async {
                    setState(() => _showThinking = !_showThinking);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_thinkingKey, _showThinking);
                  },
                  icon: Icon(
                    _showThinking
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 17,
                  ),
                  label: const Text('Matches', maxLines: 1),
                ),
              ),
            ],
          );
          Widget idle() => Column(
            children: [
              const SizedBox(height: 24),
              const SizedBox(
                width: 140,
                height: 150,
                child: RecallWireframe(thinking: false),
              ),
              const SizedBox(height: 10),
              const Text(
                'A little detail is all it takes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell me what you remember.',
                style: TextStyle(color: Color(0xFF9D93AC), fontSize: 12),
              ),
            ],
          );
          Widget thinkingPanels() => LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 650;
              final square = sideBySide
                  ? 300.0
                  : constraints.maxWidth.clamp(0.0, 340.0);
              final network = Container(
                key: const ValueKey('thinking-logic-card'),
                width: square,
                height: 240,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEAF7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2DBEF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Icon(Icons.hub_outlined, size: 16, color: _purple),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'How matches work',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RecallNetwork(
                        results: results,
                        query: p.searchQuery,
                        thinking: busy,
                      ),
                    ),
                  ],
                ),
              );
              final activity = RecallActivity(
                query: p.searchQuery,
                connections: p.connections,
                results: results,
                aiSearching: p.aiSearching,
                compact: true,
              );
              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    network,
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 240,
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 0),
                            child: activity,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: network),
                  const SizedBox(height: 12),
                  activity,
                ],
              );
            },
          );
          final matches = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      active
                          ? '${results.length} ${results.length == 1 ? 'connection' : 'connections'} found'
                          : '',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (active)
                    TextButton(
                      onPressed: () {
                        _query.clear();
                        _debounce?.cancel();
                        p.clearFilters();
                        setState(() => _typing = false);
                      },
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: _purple, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.person_search_outlined,
                        size: 32,
                        color: _purple,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        p.connections.isEmpty
                            ? 'No saved people match yet.'
                            : 'Try a different detail or clear your filters.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF8B8295),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (results.isNotEmpty) ...[
                const Text(
                  'Top match',
                  style: TextStyle(color: _purple, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                VisitingCardDeck(
                  key: const ValueKey('top-recall-match'),
                  ranked: true,
                  entries: [_resultEntry(results.first, 0)],
                ),
                if (results.length > 1) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'Other matches',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  VisitingCardDeck(
                    compact: true,
                    ranked: true,
                    rankStart: 2,
                    entries: [
                      for (var i = 1; i < results.length; i++)
                        _resultEntry(results[i], i),
                    ],
                  ),
                ],
              ],
            ],
          );
          return Padding(
            padding: EdgeInsets.all(wide ? 28 : 18),
            child: Column(
              children: [
                input,
                const SizedBox(height: 12),
                Expanded(
                  child: !active
                      ? SingleChildScrollView(
                          child: Column(
                            children: [
                              if (!keyboard) idle(),
                              if (busy)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Following your memory…',
                                    style: TextStyle(
                                      color: _purple,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_showThinking && !keyboard) ...[
                                    const SizedBox(height: 6),
                                    thinkingPanels(),
                                    const SizedBox(height: 12),
                                  ],
                                  matches,
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
