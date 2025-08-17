class User {
  final String uid;
  final String name;

  User({required this.uid, required this.name});

  // Factory method for creating a User instance from a map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
    );
  }

  // Convert a User instance to a map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
    };
  }
}
