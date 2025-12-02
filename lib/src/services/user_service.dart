import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  final String _baseUrl = dotenv.env['API_EMPRESA'] ?? '';

  // Obtener el token guardado
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Obtener todos los usuarios
  Future<List<dynamic>> getUsuarios() async {
    try {
      final token = await _getToken();
      final url = '${_baseUrl}api/v1/usuario';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        throw Exception('Error al obtener usuarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getUsuarios: $e');
      rethrow;
    }
  }

  // Crear un nuevo usuario
  Future<bool> crearUsuario({
    required String nombre,
    required String apellido,
    required String telefono,
    required String gmail,
    required String codigo,
    required String usuario,
    required String password,
  }) async {
    try {
      final url = '${_baseUrl}api/v1/usuario';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "nombre": nombre,
          "apellido": apellido,
          "telefono": telefono,
          "gmail": gmail,
          "codigo": codigo,
          "usuario": usuario,
          "password": password,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error en crearUsuario: $e');
      return false;
    }
  }

  // Eliminar un usuario
  Future<bool> eliminarUsuario(int id) async {
    try {
      final token = await _getToken();
      final url = '${_baseUrl}api/v1/usuario/$id';
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error en eliminarUsuario: $e');
      return false;
    }
  }

  // Actualizar un usuario
  Future<bool> actualizarUsuario({
    required int id,
    required String nombre,
    required String apellido,
    required String telefono,
    required String gmail,
    required String codigo,
    required String usuario,
    String? password,
  }) async {
    try {
      final token = await _getToken();
      final url = '${_baseUrl}api/v1/usuario/$id';
      final body = {
        "nombre": nombre,
        "apellido": apellido,
        "telefono": telefono,
        "gmail": gmail,
        "codigo": codigo,
        "usuario": usuario,
      };

      if (password != null && password.isNotEmpty) {
        body["password"] = password;
      }

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error en actualizarUsuario: $e');
      return false;
    }
  }
}
