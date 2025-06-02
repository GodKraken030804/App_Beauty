class User {
  final String id;
  final String email;
  final String password; // En producción, esto debería ser un hash

  User({
    required this.id,
    required this.email,
    required this.password,
  });

  // Convertir de JSON a User
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      password: json['password'],
    );
  }

  // Convertir de User a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'password': password,
    };
  }
}