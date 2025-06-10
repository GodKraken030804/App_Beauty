class User {
  final String email;
  final String token;

  User({
    required this.email,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json, String email) {
    return User(
      email: email,
      token: json['token'],
    );
  }
}
