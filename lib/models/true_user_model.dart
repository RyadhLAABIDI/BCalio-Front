class User {
  final String id;
  final String email;
  final String name;
  final String? image;
  final String? about;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSeen;
  final String? geolocalisation;
  final String? screenshotToken;
  final String? rfcToken;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.image,
    this.about,
    this.phoneNumber,
    this.createdAt,
    this.updatedAt,
    this.lastSeen,
    this.geolocalisation,
    this.screenshotToken,
    this.rfcToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '', // Provide a default value if null
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] as String?,
      about: json['about'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String)
          : null,
      geolocalisation: json['geolocalisation'] as String?,
      screenshotToken: json['screenshotToken'] as String?,
      rfcToken: json['rfcToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'image': image,
      'about': about,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastSeen': lastSeen?.toIso8601String(),
      'geolocalisation': geolocalisation,
      'screenshotToken': screenshotToken,
      'rfcToken': rfcToken,
    };
  }
}
