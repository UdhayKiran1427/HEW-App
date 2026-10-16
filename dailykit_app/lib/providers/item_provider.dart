import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_endpoints.dart';
import '../models/item_model.dart';

class ItemProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

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

  // 1. Fetch Items with optional search & tag
  Future<void> fetchItems({String? searchQuery, String? tag, bool refresh = false}) async {
    if (searchQuery != null) _currentSearchQuery = searchQuery;
    if (tag != null) _selectedTag = tag.isEmpty ? null : tag;

    if (_items.isEmpty || refresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final Map<String, dynamic> params = {};
      if (_currentSearchQuery.isNotEmpty) {
        params['q'] = _currentSearchQuery;
      }
      if (_selectedTag != null && _selectedTag!.isNotEmpty) {
        params['tag'] = _selectedTag;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.items,
        queryParameters: params,
      );

      if (response.data['success'] == true) {
        final List list = response.data['data']['items'];
        _items = list.map((item) => ItemModel.fromJson(item)).toList();
        _errorMessage = null;
      }
    } on DioException catch (e) {
      _errorMessage = e.message ?? 'Failed to load items.';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Fetch Single Item with complete Location History
  Future<ItemModel?> fetchItemDetails(int itemId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.itemDetails(itemId));
      if (response.data['success'] == true) {
        return ItemModel.fromJson(response.data['data']['item']);
      }
    } catch (_) {}
    return null;
  }

  // 3. Add Item
  Future<bool> addItem({
    required String name,
    required String currentLocation,
    String? photoUrl,
    String? tags,
    String? inUseBy,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.items,
        data: {
          'name': name.trim(),
          'current_location': currentLocation.trim(),
          'photo_url': photoUrl,
          'tags': tags,
          'in_use_by': inUseBy,
        },
      );

      if (response.data['success'] == true) {
        final created = ItemModel.fromJson(response.data['data']['item']);
        _items.insert(0, created);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    return false;
  }

  // 4. Update Item
  Future<bool> updateItem({
    required int itemId,
    required String name,
    String? photoUrl,
    String? tags,
    String? inUseBy,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        ApiEndpoints.itemDetails(itemId),
        data: {
          'name': name.trim(),
          'photo_url': photoUrl,
          'tags': tags,
          'in_use_by': inUseBy,
        },
      );

      if (response.data['success'] == true) {
        final updated = ItemModel.fromJson(response.data['data']['item']);
        final idx = _items.indexWhere((i) => i.id == itemId);
        if (idx != -1) {
          _items[idx] = updated;
          notifyListeners();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  // 5. Mark Item as "Moved"
  Future<bool> moveItem({
    required int itemId,
    required String newLocation,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.moveItem(itemId),
        data: {
          'new_location': newLocation.trim(),
          'notes': notes,
        },
      );

      if (response.data['success'] == true) {
        final updated = ItemModel.fromJson(response.data['data']['item']);
        final idx = _items.indexWhere((i) => i.id == itemId);
        if (idx != -1) {
          _items[idx] = updated;
          notifyListeners();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  // 6. Delete Item
  Future<bool> deleteItem(int itemId) async {
    try {
      final response = await _apiClient.dio.delete(ApiEndpoints.itemDetails(itemId));
      if (response.data['success'] == true) {
        _items.removeWhere((i) => i.id == itemId);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Filter tags helper
  void setTagFilter(String? tag) {
    _selectedTag = tag;
    fetchItems();
  }
}

