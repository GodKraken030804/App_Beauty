import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final String _loginUrl = '${dotenv.env['API_EMPRESA']}api/v1/loginNew';

  Future<User?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'gmail': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data, email);
      } else {
        print('Error de login: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Excepción en login: $e');
      return null;
    }
  }
}
