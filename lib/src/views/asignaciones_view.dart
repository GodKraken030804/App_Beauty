import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// Modelo de asignación
class AsignacionModel {
  final int id;
  final int idCurso;
  final int idEncargado;
  final String excel;

  AsignacionModel({
    required this.id,
    required this.idCurso,
    required this.idEncargado,
    required this.excel,
  });

  factory AsignacionModel.fromJson(Map<String, dynamic> json) {
    return AsignacionModel(
      id: json['id'],
      idCurso: json['id_curso'],
      idEncargado: json['id_encargado'],
      excel: json['excel'],
    );
  }
}

class AsignacionesView extends StatefulWidget {
  const AsignacionesView({super.key});

  @override
  State<AsignacionesView> createState() => _AsignacionesViewState();
}

class _AsignacionesViewState extends State<AsignacionesView> {
  final String baseUrl = dotenv.env['API_EMPRESA'] ?? '';
  final String apiGateway = dotenv.env['API_GATEWAY'] ?? '';
  List<AsignacionModel> _asignaciones = [];
  bool _isLoading = true;
  String? _error;
  // Catálogos para mostrar nombres
  Map<int, String> _cursosNombres = {};
  Map<int, String> _encargadosNombres = {};
  bool _loadingCatalogos = false;

  @override
  void initState() {
    super.initState();
    _cargarAsignaciones();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    setState(() => _loadingCatalogos = true);
    try {
      // Cursos
      final respCursos = await http.get(Uri.parse('${baseUrl}api/v1/curso'));
      if (respCursos.statusCode == 200) {
        final List data = json.decode(respCursos.body);
        final mapCursos = <int, String>{};
        for (final c in data) {
          final id = (c['id'] is String)
              ? int.tryParse(c['id'])
              : (c['id'] as num?)?.toInt();
          if (id != null) {
            final nombre = (c['nombre'] ?? '').toString();
            final ciudad = (c['ciudad'] ?? '').toString();
            mapCursos[id] = ciudad.isNotEmpty ? '$nombre - $ciudad' : nombre;
          }
        }
        if (mounted) setState(() => _cursosNombres = mapCursos);
      }

      // Usuarios (encargados)
      final respUsers = await http.get(Uri.parse('${baseUrl}api/v1/usuario'));
      if (respUsers.statusCode == 200) {
        final List data = json.decode(respUsers.body);
        final mapUsers = <int, String>{};
        for (final u in data) {
          final rol = (u['rol'] ?? '').toString().toLowerCase();
          if (rol == 'encargado') {
            final id = (u['id'] is String)
                ? int.tryParse(u['id'])
                : (u['id'] as num?)?.toInt();
            if (id != null) {
              final nombre =
                  (u['nombre'] ?? u['gmail'] ?? 'Encargado').toString();
              mapUsers[id] = nombre;
            }
          }
        }
        if (mounted) setState(() => _encargadosNombres = mapUsers);
      }
    } catch (_) {
      // Si falla, seguimos mostrando solo IDs
    } finally {
      if (mounted) setState(() => _loadingCatalogos = false);
    }
  }

  Future<void> _cargarAsignaciones() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response =
          await http.get(Uri.parse('${baseUrl}api/v1/asignar-curso'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _asignaciones = data.map((e) => AsignacionModel.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Error al cargar asignaciones (${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error de conexión: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _actualizarExcel(int id, int idCurso, int idEncargado) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final fileName = result.files.single.name;
        final bytes = result.files.single.bytes!;

        var uri = Uri.parse('${apiGateway}asignarcurso/admin/$id');
        var request = http.MultipartRequest('PUT', uri);

        request.fields['id_curso'] = idCurso.toString();
        request.fields['id_encargado'] = idEncargado.toString();

        request.files.add(
          http.MultipartFile.fromBytes(
            'excel',
            bytes,
            filename: fileName,
          ),
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Excel actualizado con éxito"),
              backgroundColor: Colors.green.shade600,
            ),
          );
          _cargarAsignaciones();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error al actualizar el Excel: ${response.body}"),
              backgroundColor: Colors.red.shade400,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al subir el archivo: $e"),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  Future<void> _nuevaAsignacion() async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}api/v1/asignar-curso'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id_curso": 1,
          "id_encargado": 2,
          "excel": "http://ejemplo.com/archivo.csv"
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Asignación creada con éxito"),
            backgroundColor: Colors.green.shade600,
          ),
        );
        _cargarAsignaciones();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Error al crear asignación"),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error de conexión: $e"),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  Future<void> _eliminarAsignacion(int id) async {
    // Confirmación antes de eliminar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar asignación'),
        content: const Text(
            '¿Seguro que deseas eliminar esta asignación? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // Preferimos usar el mismo dominio del listado (baseUrl) para evitar problemas de conexión/CORS en web
      final uri = Uri.parse('${baseUrl}api/v1/asignar-curso/$id');
      final resp = await http.delete(uri);

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Asignación eliminada'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        _cargarAsignaciones();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('No se pudo eliminar (${resp.statusCode}): ${resp.body}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        title: Text(
          'Asignaciones',
          style: GoogleFonts.poppins(
            color: const Color(0xFFF26AB6),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF26AB6)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF26AB6)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF26AB6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _cargarAsignaciones,
                        label: Text(
                          'Reintentar',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/Logo.png',
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Asignaciones Registradas',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFF26AB6),
                                    ),
                                  ),
                                ),
                                if (_loadingCatalogos)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFF26AB6)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_asignaciones.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'No hay asignaciones disponibles',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ..._asignaciones.map(
                                (asig) => Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 4,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  const Color(0xFFF26AB6),
                                              child: const Icon(Icons.school,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                "Asignación ${asig.id}",
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(Icons.class_,
                                                color: Color(0xFFF26AB6)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _cursosNombres.containsKey(
                                                        asig.idCurso)
                                                    ? 'Curso: ${_cursosNombres[asig.idCurso]} (ID: ${asig.idCurso})'
                                                    : 'Curso ID: ${asig.idCurso}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.person,
                                                color: Color(0xFFF26AB6)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _encargadosNombres.containsKey(
                                                        asig.idEncargado)
                                                    ? 'Encargado: ${_encargadosNombres[asig.idEncargado]} (ID: ${asig.idEncargado})'
                                                    : 'Encargado ID: ${asig.idEncargado}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.description,
                                                color: Color(0xFFF26AB6)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Excel: ${asig.excel}",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _actualizarExcel(
                                                  asig.id,
                                                  asig.idCurso,
                                                  asig.idEncargado,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFFF26AB6),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                    Icons.upload_file,
                                                    size: 18),
                                                label: Text(
                                                  'Subir Excel',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _eliminarAsignacion(
                                                        asig.id),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.red.shade600,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18),
                                                label: Text(
                                                  'Eliminar',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _nuevaAsignacion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            shadowColor: Colors.grey.withOpacity(0.5),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFF26AB6),
                                  const Color(0xFFAA57EC)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              constraints: const BoxConstraints(minHeight: 50),
                              child: Text(
                                'Nueva Asignación',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFF26AB6), const Color(0xFFAA57EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: SizedBox(
          height: 70,
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Principal',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Mi Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
