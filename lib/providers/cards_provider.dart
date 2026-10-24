import 'package:flutter/material.dart';
import '../services/text_safety.dart';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import '../services/storage_service.dart';

class CardsProvider extends ChangeNotifier {
  static const freeCardLimit = 5;
  bool get canCreateCard => _cards.length < freeCardLimit;
  int get remainingCardSlots =>
      (freeCardLimit - _cards.length).clamp(0, freeCardLimit);
  final StorageService _storageService;

  void Function()? onLocalChange;
  Future<void> Function(ContactCard)? onValidateText;
  List<ContactCard> _cards = [];
  bool _isLoading = true;
  EventContext?
  _activeEventMode; // Event stamping mode for currently attended event

  CardsProvider(this._storageService) {
    loadCards();
  }

  List<ContactCard> get cards => _cards;
  String get suggestedCardColour {
    const colours = [
      '#2563EB',
      '#0D9488',
      '#7C3AED',
      '#D97706',
      '#BE185D',
      '#164E63',
      '#18181B',
    ];
    int distance(String a, String b) {
      final x = int.tryParse(a.replaceAll('#', ''), radix: 16) ?? 0;
      final y = int.tryParse(b.replaceAll('#', ''), radix: 16) ?? 0;
      var result = 0;
      for (final shift in [0, 8, 16]) {
        final delta = ((x >> shift) & 255) - ((y >> shift) & 255);
        result += delta * delta;
      }
      return result;
    }

    for (final colour in colours) {
      if (_cards.every((c) => distance(colour, c.themeColorHex) > 6000)) {
        return colour;
      }
    }
    return colours[_cards.length % colours.length];
  }

  bool get isLoading => _isLoading;
  EventContext? get activeEventMode => _activeEventMode;

  ContactCard? get defaultCard {
    if (_cards.isEmpty) return null;
    return _cards.where((c) => c.isDefault).firstOrNull;
  }

  /// The primary card is the front face; private ranks survive cloud merges.
  List<ContactCard> get walletCards {
    final positions = {for (var i = 0; i < _cards.length; i++) _cards[i].id: i};
    final ordered = [..._cards]
      ..sort((a, b) {
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        final rank = (a.walletOrder ?? positions[a.id]!).compareTo(
          b.walletOrder ?? positions[b.id]!,
        );
        return rank != 0 ? rank : positions[a.id]!.compareTo(positions[b.id]!);
      });
    return ordered;
  }

  Future<void> reorderWallet(List<String> ids) async {
    final current = walletCards;
    if (ids.length != current.length ||
        ids.toSet().length != ids.length ||
        !ids.toSet().containsAll(current.map((c) => c.id))) {
      throw ArgumentError('Reordering must include each card exactly once.');
    }
    // Reordering cannot bypass the free-plan lock or move locked cards into active slots.
    final active = current.take(freeCardLimit).map((c) => c.id).toSet();
    if (!active.containsAll(ids.take(freeCardLimit)) ||
        ids.skip(freeCardLimit).join('|') !=
            current.skip(freeCardLimit).map((c) => c.id).join('|')) {
      throw StateError('Only active cards can be reordered.');
    }
    if (ids.isEmpty) return;
    final byId = {for (final card in current) card.id: card};
    final reordered = <ContactCard>[];
    for (var i = 0; i < ids.length; i++) {
      final card = byId[ids[i]]!;
      final primary = i == 0;
      reordered.add(
        card.walletOrder == i && card.isDefault == primary
            ? card
            : card.copyWith(
                walletOrder: i,
                isDefault: primary,
                updatedAt: _storageService.versionFor(
                  'card',
                  card.id,
                  card.updatedAt,
                ),
              ),
      );
    }
    final scope = _storageService.scope;
    await _storageService.saveCards(reordered);
    if (scope != _storageService.scope) return;
    _cards = reordered;
    onLocalChange?.call();
    notifyListeners();
  }

  bool isCardLocked(String id) {
    final index = walletCards.indexWhere((card) => card.id == id);
    return index >= freeCardLimit;
  }

  StorageService get storageService => _storageService;

  void clearForAccountSwitch() {
    _cards = [];
    _activeEventMode = null;
    _isLoading = true;
    notifyListeners();
  }

  Future<void> mergeCloud(
    List<ContactCard> cards,
    List<Map<String, dynamic>> deleted,
  ) async {
    final merged = {for (final card in _cards) card.id: card};
    for (final card in cards) {
      if (!merged.containsKey(card.id) ||
          card.updatedAt.isAfter(merged[card.id]!.updatedAt)) {
        merged[card.id] = card;
      } else if (card.updatedAt.isAtSameMomentAs(merged[card.id]!.updatedAt) &&
          merged[card.id]!.avatarUrl.startsWith('data:')) {
        merged[card.id] = merged[card.id]!.copyWith(avatarUrl: card.avatarUrl);
      }
    }
    for (final item in deleted.where((e) => e['kind'] == 'card')) {
      final existing = merged[item['id']];
      if (existing != null &&
          !existing.updatedAt.isAfter(DateTime.parse(item['updatedAt']))) {
        merged.remove(item['id']);
      }
    }
    _cards = merged.values.toList();
    await _storageService.saveCards(_cards);
    notifyListeners();
  }

  Future<void> loadCards() async {
    _isLoading = true;
    notifyListeners();
    final scope = _storageService.scope;
    final cards = await _storageService.loadCards();
    if (scope != _storageService.scope) return;
    _cards = cards;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _storageService.setOnboardingCompleted(true);
    notifyListeners();
  }

  void setActiveEventMode(EventContext? event) {
    _activeEventMode = event;
    notifyListeners();
  }

  Future<void> addCard(ContactCard card) async {
    TextSafety.validateFields(card.toJson());
    final scope = _storageService.scope;
    await onValidateText?.call(card);
    if (scope != _storageService.scope) throw StateError('Account changed.');
    if (!canCreateCard) {
      throw StateError(
        'The free plan includes five cards. Edit or remove a card to add another.',
      );
    }
    card = card.copyWith(
      updatedAt: _storageService.versionFor('card', card.id, card.updatedAt),
    );
    if (card.isDefault) {
      _cards = _cards
          .map(
            (c) => c.copyWith(
              isDefault: false,
              updatedAt: _storageService.versionFor('card', c.id, c.updatedAt),
            ),
          )
          .toList();
    }
    _cards.insert(0, card);
    await _storageService.saveCards(_cards);
    onLocalChange?.call();
    notifyListeners();
  }

  Future<void> updateCard(ContactCard updatedCard) async {
    TextSafety.validateFields(updatedCard.toJson());
    final scope = _storageService.scope;
    await onValidateText?.call(updatedCard);
    if (scope != _storageService.scope) throw StateError('Account changed.');
    if (isCardLocked(updatedCard.id)) {
      throw StateError(
        'Free accounts can use up to five cards. Remove a card to unlock this one.',
      );
    }
    updatedCard = updatedCard.copyWith(
      updatedAt: _storageService.versionFor(
        'card',
        updatedCard.id,
        _cards.where((c) => c.id == updatedCard.id).firstOrNull?.updatedAt,
      ),
    );
    if (updatedCard.isDefault) {
      _cards = _cards
          .map(
            (c) => c.id == updatedCard.id
                ? c
                : c.copyWith(
                    isDefault: false,
                    updatedAt: _storageService.versionFor(
                      'card',
                      c.id,
                      c.updatedAt,
                    ),
                  ),
          )
          .toList();
    }
    final index = _cards.indexWhere((c) => c.id == updatedCard.id);
    if (index != -1) {
      _cards[index] = updatedCard;
      await _storageService.saveCards(_cards);
      onLocalChange?.call();
      notifyListeners();
    }
  }

  Future<void> deleteCard(String cardId) async {
    await _storageService.markDeleted(
      'card',
      cardId,
      _storageService.versionFor(
        'card',
        cardId,
        _cards.where((c) => c.id == cardId).firstOrNull?.updatedAt,
      ),
    );
    _cards.removeWhere((c) => c.id == cardId);
    await _storageService.saveCards(_cards);
    onLocalChange?.call();
    notifyListeners();
  }

  Future<void> setDefaultCard(String cardId) async {
    if (isCardLocked(cardId)) {
      throw StateError('Free accounts can use up to five cards.');
    }
    if (!_cards.any((c) => c.id == cardId)) return;
    _cards = _cards
        .map(
          (c) => c.copyWith(
            isDefault: c.id == cardId,
            updatedAt: _storageService.versionFor('card', c.id, c.updatedAt),
          ),
        )
        .toList();
    await _storageService.saveCards(_cards);
    onLocalChange?.call();
    notifyListeners();
  }
}
