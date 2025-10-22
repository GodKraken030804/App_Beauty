import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:app_beauty/src/views/mi_perfil_admin.dart';
import 'package:app_beauty/src/views/admin_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
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
  PlatformFile? excelFile;
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
    try {
      final data = await _fetchCursos();
      setState(() {
        cursos = data;
        isLoadingCursos = false;
      });
    } catch (e) {
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
      final encargadosFiltrados =
          data.where((u) => (u['usuario']?.toLowerCase() == 'encargado')).toList();
      print(' Encargados encontrados: ${encargadosFiltrados.length}');
      return encargadosFiltrados;
    }
    print(' Error al obtener encargados');
    return [];
  }

  Future<List> _fetchCursos() async {
    print(' Iniciando fetch de cursos...');
    final url = Uri.parse('${dotenv.env['API_EMPRESA']!.trim()}api/v1/curso');
    print(' URL de la API cursos: $url');
    final response = await http.get(url);
    print(' Status Code cursos: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Cursos recibidos: ${data.length}');
      return data;
    }
    print(' Error al obtener cursos');
    return [];
  }

  Future<bool> _asignarCurso() async {
    try {
      // Validaciones iniciales
      if (selectedOption1 == null || selectedOption2 == null) {
        throw Exception('Debe seleccionar un encargado y un curso');
      }

      if (excelFile == null) {
        throw Exception('Debe seleccionar un archivo Excel');
      }

      // Obtener token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('No se encontró el token de autenticación');
      }

      // Preparar URL
      final baseUrl = dotenv.env['API_GATEWAY']!.trim();
      final uri = Uri.parse('${baseUrl}asignarcurso/admin');

      print('\nDATOS DE LA ASIGNACIÓN:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('URL: $uri');
      print('ID Encargado: $selectedOption1');
      print('ID Curso: $selectedOption2');
      print(
          'Archivo: ${excelFile!.name} (${(excelFile!.size / 1024).toStringAsFixed(2)} KB)');

      // Crear request
      var request = http.MultipartRequest('POST', uri);

      // Agregar campos form-data
      request.fields['id_curso'] = selectedOption2!;
      request.fields['id_encargado'] = selectedOption1!;

      if (kIsWeb) {
        // Para web usamos los bytes directamente
        final contentType = excelFile!.name.endsWith('.csv')
            ? MediaType('text', 'csv')
            : MediaType('application',
                'vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        print('   └─ Content-Type: ${contentType.mimeType}');

        request.files.add(http.MultipartFile.fromBytes(
          'excel',
          excelFile!.bytes!,
          filename: excelFile!.name,
          contentType: contentType,
        ));
        print('   └─ Tipo de envío: Bytes (Web)');
      } else {
        // Para plataformas nativas usamos el path
        request.files.add(await http.MultipartFile.fromPath(
          'excel',
          excelFile!.path!,
        ));
        print('   └─ Tipo de envío: Path (Nativo)');
        print('   └─ Ruta: ${excelFile!.path}');
      }

      // Agregar token de autorización
      request.headers['Authorization'] = 'Bearer $token';

      // Enviar request
      var streamedResponse = await request.send();
      final respBody = await streamedResponse.stream.bytesToString();

      print('Código de estado: ${streamedResponse.statusCode}');
      print('Respuesta: $respBody');

      if (streamedResponse.statusCode == 201 ||
          streamedResponse.statusCode == 200) {
        return true;
      } else {
        throw Exception(
            "Error al asignar curso: ${streamedResponse.statusCode} - $respBody");
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

  Future<void> pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true, // Importante: esto nos da acceso a los bytes del archivo
    );

    if (result != null) {
      setState(() {
        excelFile = result.files.single;
      });
    }
  }

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
                            horizontal: 16, vertical: 6),
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
                                          color: Color(0xFFF26AB6)),
                                      const SizedBox(width: 8),
                                      Text('Selecciona un encargado',
                                          style: GoogleFonts.poppins(
                                              color: Colors.grey[600])),
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
                            horizontal: 16, vertical: 6),
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
                                          color: Color(0xFFF26AB6)),
                                      const SizedBox(width: 8),
                                      Text('Selecciona un curso',
                                          style: GoogleFonts.poppins(
                                              color: Colors.grey[600])),
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

                    // Archivo Excel
                    InkWell(
                      onTap: pickExcelFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return FadeTransition(
                                      opacity: animation, child: child);
                                },
                                child: Text(
                                  excelFile != null
                                      ? "Archivo subido ✓"
                                      : "Subir archivo Excel",
                                  key: ValueKey<bool>(excelFile != null),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: excelFile != null
                                        ? const Color(0xFF4CAF50)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                                excelFile != null
                                    ? Icons.check_circle
                                    : Icons.upload_file,
                                color: excelFile != null
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF26AB6)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Botón Asignar de ancho completo (sin botón Cancelar)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedOption1 != null &&
                              selectedOption2 != null &&
                              excelFile != null) {
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
