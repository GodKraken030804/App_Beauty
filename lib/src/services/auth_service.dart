import '../models/user_model.dart';

class AuthService {
  // Base de datos temporal (en producción usa Firebase, SQLite, etc.)
  final List<User> _users = [
    User(id: '1', email: 'admin@example.com', password: '123456'),
  ];

  // Método para iniciar sesión
  Future<User?> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // Simular llamada a API
    
    try {
      final user = _users.firstWhere(
        (u) => u.email == email && u.password == password,
      );
      return user;
    } catch (e) {
      return null; // No se encontró el usuario
    }
  }

  // Método para registrar usuario (opcional)
  Future<User> register(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    
    final newUser = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email,
      password: password,
    );
    
    _users.add(newUser);
    return newUser;
  }
}