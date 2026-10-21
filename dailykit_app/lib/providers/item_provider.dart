import 'package:flutter/material.dart';
import '../core/database/local_database_service.dart';
import '../models/item_model.dart';

class ItemProvider extends ChangeNotifier {
  final LocalDatabaseService _localDb = LocalDatabaseService();

  List<ItemModel> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentSearchQuery = '';
  String? _selectedTag;

  List<ItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentSearchQuery => _currentSearchQuery;
  String? get selectedTag => _selectedTag;

  // 1. Fetch Items with optional search & tag directly from SQLite
  Future<void> fetchItems({String? searchQuery, String? tag, bool refresh = false}) async {
    if (searchQuery != null) _currentSearchQuery = searchQuery;
    if (tag != null) _selectedTag = tag.isEmpty ? null : tag;

    if (_items.isEmpty || refresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await _localDb.getItems(
        query: _currentSearchQuery,
        tag: _selectedTag,
      );
      _items = list.map((item) => ItemModel.fromJson(item)).toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Fetch Single Item with complete Location History from SQLite
  Future<ItemModel?> fetchItemDetails(int itemId) async {
    try {
      final itemMap = await _localDb.getItemDetails(itemId);
      if (itemMap != null) {
        return ItemModel.fromJson(itemMap);
      }
    } catch (_) {}
    return null;
  }

  // 3. Add Item to SQLite
  Future<bool> addItem({
    required String name,
    required String currentLocation,
    String? photoUrl,
    String? tags,
    String? inUseBy,
  }) async {
    try {
      final createdMap = await _localDb.createItem(
        name: name,
        currentLocation: currentLocation,
        photoUrl: photoUrl,
        tags: tags,
        inUseBy: inUseBy,
      );
      final created = ItemModel.fromJson(createdMap);
      _items.insert(0, created);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // 4. Update Item in SQLite
  Future<bool> updateItem({
    required int itemId,
    required String name,
    String? photoUrl,
    String? tags,
    String? inUseBy,
  }) async {
    try {
      final currentItem = await _localDb.getItemDetails(itemId);
      final currentLocation = currentItem?['current_location'] ?? 'General Storage';

      final updatedMap = await _localDb.updateItem(
        itemId: itemId,
        name: name,
        currentLocation: currentLocation,
        tags: tags,
        inUseBy: inUseBy,
      );

      final updated = ItemModel.fromJson(updatedMap);
      final idx = _items.indexWhere((i) => i.id == itemId);
      if (idx != -1) {
        _items[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // 5. Mark Item as "Moved" in SQLite (stores location history)
  Future<bool> moveItem({
    required int itemId,
    required String newLocation,
    String? notes,
  }) async {
    try {
      final updatedMap = await _localDb.updateItemLocation(
        itemId: itemId,
        newLocation: newLocation,
      );

      final updated = ItemModel.fromJson(updatedMap);
      final idx = _items.indexWhere((i) => i.id == itemId);
      if (idx != -1) {
        _items[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // 6. Delete Item in SQLite
  Future<bool> deleteItem(int itemId) async {
    try {
      await _localDb.deleteItem(itemId);
      _items.removeWhere((i) => i.id == itemId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Filter tags helper
  void setTagFilter(String? tag) {
    _selectedTag = tag;
    fetchItems(refresh: true);
  }
}
