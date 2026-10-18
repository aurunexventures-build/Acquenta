import 'package:flutter/material.dart';
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
  List<ContactCard> _cards = [];
  bool _isLoading = true;
  EventContext?
  _activeEventMode; // Event stamping mode for currently attended event

  CardsProvider(this._storageService) {
    loadCards();
  }

  List<ContactCard> get cards => _cards;
  bool get isLoading => _isLoading;
  EventContext? get activeEventMode => _activeEventMode;

  ContactCard? get defaultCard {
    if (_cards.isEmpty) return null;
    return _cards.where((c) => c.isDefault).firstOrNull;
  }

  /// Primary is an explicit choice; remaining cards keep their saved order.
  List<ContactCard> get walletCards => [
    ?defaultCard,
    ..._cards.where((c) => c.id != defaultCard?.id),
  ];

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
