class ItemLocationHistory {
  final int id;
  final int itemId;
  final String previousLocation;
  final String newLocation;
  final String? notes;
  final String changedAt;

  ItemLocationHistory({
    required this.id,
    required this.itemId,
    required this.previousLocation,
    required this.newLocation,
    this.notes,
    required this.changedAt,
  });

  factory ItemLocationHistory.fromJson(Map<String, dynamic> json) {
    return ItemLocationHistory(
      id: json['id'] as int,
      itemId: json['item_id'] as int? ?? 0,
      previousLocation: json['previous_location'] as String? ?? '',
      newLocation: json['new_location'] as String? ?? '',
      notes: json['notes'] as String?,
      changedAt: json['changed_at'] as String? ?? '',
    );
  }
}

class ItemModel {
  final int id;
  final int userId;
  final String name;
  final String currentLocation;
  final String? photoUrl;
  final List<String> tags;
  final String? inUseBy;
  final String? createdAt;
  final String? updatedAt;
  final List<ItemLocationHistory> history;

  ItemModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.currentLocation,
    this.photoUrl,
    this.tags = const [],
    this.inUseBy,
    this.createdAt,
    this.updatedAt,
    this.history = const [],
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['tags'] != null && json['tags'].toString().isNotEmpty) {
      parsedTags = json['tags'].toString().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }

    List<ItemLocationHistory> parsedHistory = [];
    if (json['history'] != null && json['history'] is List) {
      parsedHistory = (json['history'] as List)
          .map((h) => ItemLocationHistory.fromJson(h as Map<String, dynamic>))
          .toList();
    }

    return ItemModel(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      currentLocation: json['current_location'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      tags: parsedTags,
      inUseBy: json['in_use_by'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      history: parsedHistory,
    );
  }

  ItemModel copyWith({
    int? id,
    int? userId,
    String? name,
    String? currentLocation,
    String? photoUrl,
    List<String>? tags,
    String? inUseBy,
    String? createdAt,
    String? updatedAt,
    List<ItemLocationHistory>? history,
  }) {
    return ItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      currentLocation: currentLocation ?? this.currentLocation,
      photoUrl: photoUrl ?? this.photoUrl,
      tags: tags ?? this.tags,
      inUseBy: inUseBy ?? this.inUseBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
    );
  }
}

