import 'package:flutter/material.dart';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import '../services/storage_service.dart';

class CardsProvider extends ChangeNotifier {
  final StorageService _storageService;

  List<ContactCard> _cards = [];
  bool _isLoading = true;
  EventContext? _activeEventMode; // Event stamping mode for currently attended event

  CardsProvider(this._storageService) {
    loadCards();
  }

  List<ContactCard> get cards => _cards;
  bool get isLoading => _isLoading;
  EventContext? get activeEventMode => _activeEventMode;

  ContactCard? get defaultCard {
    if (_cards.isEmpty) return null;
    return _cards.firstWhere((c) => c.isDefault, orElse: () => _cards.first);
  }

  StorageService get storageService => _storageService;

  Future<void> loadCards() async {
    _isLoading = true;
    notifyListeners();
    _cards = await _storageService.loadCards();
    _isLoading = false;
    notifyListeners();
  }

  void setActiveEventMode(EventContext? event) {
    _activeEventMode = event;
    notifyListeners();
  }

  Future<void> addCard(ContactCard card) async {
    if (card.isDefault) {
      _cards = _cards.map((c) => c.copyWith(isDefault: false)).toList();
    }
    _cards.insert(0, card);
    await _storageService.saveCards(_cards);
    notifyListeners();
  }

  Future<void> updateCard(ContactCard updatedCard) async {
    if (updatedCard.isDefault) {
      _cards = _cards.map((c) => c.id == updatedCard.id ? c : c.copyWith(isDefault: false)).toList();
    }
    final index = _cards.indexWhere((c) => c.id == updatedCard.id);
    if (index != -1) {
      _cards[index] = updatedCard;
      await _storageService.saveCards(_cards);
      notifyListeners();
    }
  }

  Future<void> deleteCard(String cardId) async {
    _cards.removeWhere((c) => c.id == cardId);
    if (_cards.isNotEmpty && !_cards.any((c) => c.isDefault)) {
      _cards[0] = _cards[0].copyWith(isDefault: true);
    }
    await _storageService.saveCards(_cards);
    notifyListeners();
  }

  Future<void> setDefaultCard(String cardId) async {
    _cards = _cards.map((c) => c.copyWith(isDefault: c.id == cardId)).toList();
    await _storageService.saveCards(_cards);
    notifyListeners();
  }
}
