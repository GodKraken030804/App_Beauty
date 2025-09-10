import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/asignacion_model.dart';

class AsignacionService {
  final String _baseUrl = dotenv.env['API_EMPRESA'] ?? '';

  Future<List<AsignacionModel>> getAsignaciones() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl api/v1/asignar-curso'),
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((data) => AsignacionModel.fromJson(data)).toList();
      } else {
        throw Exception('Error al cargar las asignaciones');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
