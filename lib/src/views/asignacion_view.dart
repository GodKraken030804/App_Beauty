import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_beauty/src/views/mi_perfil_admin.dart';
import 'package:app_beauty/src/views/admin_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:another_flushbar/flushbar.dart';

class AsignacionView extends StatefulWidget {
  const AsignacionView({super.key});

  @override
  State<AsignacionView> createState() => _AsignacionViewState();
}

class _AsignacionViewState extends State<AsignacionView> {
  String? selectedOption1;
  String? selectedOption2;
  int _currentIndex = 0; // para saber en qué tab estamos
  List<dynamic> encargados = [];
  List<dynamic> cursos = [];
  bool isLoadingEncargados = true;
  bool isLoadingCursos = true;
  final List<Color> gradientColors = const [
    Color(0xFFF26AB6),
    Color(0xFFAA57EC)
  ];

  @override
  void initState() {
    super.initState();
    _loadEncargados();
    _loadCursos();
  }

  Future<void> _loadEncargados() async {
    try {
      final data = await _fetchEncargados();
      setState(() {
        encargados = data;
        isLoadingEncargados = false;
      });
    } catch (e) {
      setState(() {
        isLoadingEncargados = false;
      });
      // Aquí podrías mostrar un mensaje de error si lo deseas
    }
  }

  Future<void> _loadCursos() async {
    setState(() {
      isLoadingCursos = true;
      cursos = []; // Limpiar lista antes de recargar
    });
    try {
      final data = await _fetchCursos();
      print('🔄 Cursos cargados desde servidor: ${data.length}');
      for (var curso in data) {
        print(
            '  - Curso ID ${curso['id']}: ${curso['nombre']} - ${curso['ciudad']}');
      }
      setState(() {
        cursos = data;
        isLoadingCursos = false;
      });
    } catch (e) {
      print('❌ Error al cargar cursos: $e');
      setState(() {
        isLoadingCursos = false;
      });
      // Aquí podrías mostrar un mensaje de error si lo deseas
    }
  }

  Future<List> _fetchEncargados() async {
    print(' Iniciando fetch de encargados...');
    final url = Uri.parse('${dotenv.env['API_EMPRESA']!.trim()}api/v1/usuario');
    print(' URL de la API: $url');
    final response = await http.get(url);
    print(' Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(' Datos recibidos: ${data.length} registros');
      final encargadosFiltrados = data.where((u) {
        final usuario = (u['usuario'] ?? '').toString().toLowerCase().trim();
        // Solo mostrar usuarios con rol Encargado para evitar asignaciones incorrectas
        return usuario == 'encargado';
      }).toList();
      print(' Encargados encontrados: ${encargadosFiltrados.length}');
      return encargadosFiltrados;
    }
    print(' Error al obtener encargados');
    return [];
  }

  Future<List> _fetchCursos() async {
    print('🌐 Iniciando fetch de cursos...');
    final url = Uri.parse('${dotenv.env['API_EMPRESA']!.trim()}api/v1/curso');
    print('🌐 URL de la API cursos: $url');
    final response = await http.get(url, headers: {
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    });
    print('📡 Status Code cursos: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Cursos recibidos del servidor: ${data.length}');
      return data;
    }
    print('❌ Error al obtener cursos - Status: ${response.statusCode}');
    return [];
  }

  Future<bool> _asignarCurso() async {
    try {
      // Validaciones iniciales
      if (selectedOption1 == null || selectedOption2 == null) {
        throw Exception('Debe seleccionar un encargado y un curso');
      }

      // Obtener token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No se encontró el token de autenticación');
      }

      // Endpoint JSON simple (sin archivo) para crear asignación
      final baseEmpresa = dotenv.env['API_EMPRESA']!.trim();
      final normalized =
          baseEmpresa.endsWith('/') ? baseEmpresa : '$baseEmpresa/';
      final uri = Uri.parse('${normalized}api/v1/asignar-curso');

      print('\nDATOS DE LA ASIGNACIÓN:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('URL: $uri');
      // Logs adicionales para validar selección antes de enviar
      final encargadoSel = encargados.firstWhere(
        (e) => e['id'].toString() == selectedOption1,
        orElse: () => null,
      );
      final encargadoNombre = encargadoSel == null
          ? 'Desconocido'
          : (encargadoSel['nombre'] ?? 'Sin nombre');
      print('Encargado seleccionado: $encargadoNombre (ID: $selectedOption1)');
      print('ID Curso: $selectedOption2');
      // Crear body JSON
      final body = jsonEncode({
        'id_curso': selectedOption2,
        'id_encargado': selectedOption1,
      });

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(uri, headers: headers, body: body);
      print('Código de estado: ${response.statusCode}');
      print('Respuesta: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
            'Error al asignar curso: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  Future<bool> _mostrarDialogoConfirmacion(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo arriba
                  Center(
                    child: Image.asset(
                      'assets/images/Logo.png',
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Pregunta
                  Text(
                    '¿Está seguro que desea realizar esta asignación?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: gradientColors.first),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.poppins(
                            color: gradientColors.first,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 3,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            child: Text(
                              'Asignar',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Flujo sin archivo: ya no se requiere seleccionar Excel

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              // NavBar superior estilo Options (gradiente)
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      icon: const Icon(Icons.refresh,
                          color: Colors.white, size: 28),
                      onPressed: () {
                        setState(() {
                          isLoadingCursos = true;
                          isLoadingEncargados = true;
                        });
                        _loadCursos();
                        _loadEncargados();
                      },
                      tooltip: 'Recargar datos',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              /// 🔹 Formulario
              Container(
                padding: const EdgeInsets.all(18),
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo adentro del cuadro, arriba del título
                    Image.asset(
                      "assets/images/Logo.png",
                      height: 160,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Asignación",
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Curso
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: isLoadingEncargados
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFF26AB6)),
                                    ),
                                  ),
                                )
                              : DropdownButton<String>(
                                  value: selectedOption1,
                                  hint: Row(
                                    children: [
                                      const Icon(Icons.person,
                                          color: Color(0xFFF26AB6), size: 20),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text('Selecciona un encargado',
                                            style: GoogleFonts.poppins(
                                                color: Colors.grey[600],
                                                fontSize: 14),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                  icon: const Icon(Icons.expand_more,
                                      color: Color(0xFFF26AB6)),
                                  isExpanded: true,
                                  selectedItemBuilder: (BuildContext context) {
                                    // Muestra solo el nombre cuando está seleccionado
                                    return encargados.map<Widget>((user) {
                                      return Row(
                                        children: [
                                          const Icon(Icons.person,
                                              color: Color(0xFFF26AB6),
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              user['nombre'] ?? 'Sin nombre',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList();
                                  },
                                  items: encargados
                                      .map<DropdownMenuItem<String>>((user) {
                                    return DropdownMenuItem<String>(
                                      value: user['id'].toString(),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person,
                                              color: Color(0xFFF26AB6)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              user['nombre'] ?? 'Sin nombre',
                                              style: GoogleFonts.poppins(),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() {
                                      selectedOption1 = newValue;
                                    });
                                  },
                                ),
                        ),
                      ),
                    ),

                    // Ciudad
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: isLoadingCursos
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFF26AB6)),
                                    ),
                                  ),
                                )
                              : DropdownButton<String>(
                                  value: selectedOption2,
                                  hint: Row(
                                    children: [
                                      const Icon(Icons.menu_book,
                                          color: Color(0xFFF26AB6), size: 20),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text('Selecciona un curso',
                                            style: GoogleFonts.poppins(
                                                color: Colors.grey[600],
                                                fontSize: 14),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                  icon: const Icon(Icons.expand_more,
                                      color: Color(0xFFF26AB6)),
                                  isExpanded: true,
                                  items: cursos
                                      .map<DropdownMenuItem<String>>((curso) {
                                    return DropdownMenuItem<String>(
                                      value: curso['id'].toString(),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.menu_book,
                                              color: Color(0xFFF26AB6)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${curso['nombre']} - ${curso['ciudad']}',
                                              style: GoogleFonts.poppins(),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() {
                                      selectedOption2 = newValue;
                                    });
                                  },
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Botón Asignar de ancho completo (sin botón Cancelar)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedOption1 != null &&
                              selectedOption2 != null) {
                            // Mostrar diálogo de confirmación
                            final confirmado =
                                await _mostrarDialogoConfirmacion(context);

                            if (confirmado) {
                              // Mostrar indicador de carga
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Asignando curso..."),
                                  duration: Duration(milliseconds: 1500),
                                  backgroundColor: Color(0xFFF26AB6),
                                ),
                              );

                              final success = await _asignarCurso();

                              // Notificación tipo navbar (Flushbar) al éxito
                              if (success) {
                                Flushbar(
                                  margin: const EdgeInsets.all(20),
                                  borderRadius: BorderRadius.circular(15),
                                  backgroundColor: const Color(0xFFF26AB6),
                                  flushbarPosition: FlushbarPosition.TOP,
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.white, size: 28),
                                  titleText: Text(
                                    '¡Asignación exitosa!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  messageText: Text(
                                    'El curso ha sido asignado correctamente.',
                                    style: GoogleFonts.poppins(
                                        fontSize: 16, color: Colors.white),
                                  ),
                                  duration: const Duration(seconds: 2),
                                  animationDuration:
                                      const Duration(milliseconds: 500),
                                ).show(context);
                                await Future.delayed(
                                    const Duration(milliseconds: 800));
                                if (mounted) Navigator.of(context).pop();
                              } else {
                                // Mantener diálogo de error como antes
                                // ignore: use_build_context_synchronously
                                await showDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      title: const Text('Error',
                                          style: TextStyle(color: Colors.red)),
                                      content: const Text(
                                          'Ha ocurrido un error al asignar el curso. Por favor, intente nuevamente.'),
                                      actions: <Widget>[
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFFF26AB6)),
                                          child: const Text('Aceptar',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          onPressed: () =>
                                              Navigator.of(dialogContext).pop(),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text("Por favor complete todos los campos"),
                                backgroundColor: Color(0xFFF26AB6),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                          shadowColor: Colors.grey.withOpacity(0.5),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 50),
                            alignment: Alignment.center,
                            child: Text(
                              'Asignar',
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
            ],
          ),
        ),
      ),

      /// 🔹 BottomNavigationBar con gradiente
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 0) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AdminView()),
                (route) => false,
              );
            } else if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MiPerfilAdmin()),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Principal",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Mi Perfil",
            ),
          ],
        ),
      ),
    );
  }
}
