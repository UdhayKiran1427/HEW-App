class UserModel {
  final int id;
  final String name;
  final String email;
  final String currency;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.currency,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      currency: json['currency'] as String? ?? 'INR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'currency': currency,
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? currency,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      currency: currency ?? this.currency,
    );
  }
}

