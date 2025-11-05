import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_beauty/src/views/admin_view.dart';
import 'package:app_beauty/src/views/mi_perfil_admin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgregarProductoView extends StatefulWidget {
  const AgregarProductoView({super.key});

  @override
  State<AgregarProductoView> createState() => _AgregarProductoViewState();
}

class _AgregarProductoViewState extends State<AgregarProductoView> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _precioController = TextEditingController();
  final _precioUnitarioController = TextEditingController();
  Uint8List? _imagenBytes;
  String? _imagenNombre;

  final List<Color> gradientColors = const [
    Color(0xFFF26AB6),
    Color(0xFFAA57EC)
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imagenBytes = bytes;
        _imagenNombre = picked.name;
      });
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    // Requerir imagen seleccionada
    if (_imagenBytes == null || _imagenNombre == null) {
      _mostrarAlerta('Selecciona una imagen antes de guardar.', success: false);
      return;
    }

    try {
      final base = (dotenv.env['API_GATEWAY'] ?? '').trim();
      final url = '${base.endsWith('/') ? base : '$base/'}registrar-producto';
      final uri = Uri.parse(url);
      final request = http.MultipartRequest('POST', uri);

      // Token de autorización (si existe)
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {}

      request.headers['Accept'] = 'application/json';

      request.fields['nombre'] = _nombreController.text.trim();
      request.fields['cantidad'] = _cantidadController.text.trim();
      request.fields['precio'] = _precioController.text.trim();
      request.fields['precioUnitario'] = _precioUnitarioController.text.trim();

      // Determinar MIME type por extensión
      final filename = _imagenNombre!;
      final ext = filename.split('.').last.toLowerCase();
      MediaType mediaType;
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          mediaType = MediaType('image', 'jpeg');
          break;
        case 'png':
          mediaType = MediaType('image', 'png');
          break;
        case 'gif':
          mediaType = MediaType('image', 'gif');
          break;
        case 'webp':
          mediaType = MediaType('image', 'webp');
          break;
        default:
          mediaType = MediaType('application', 'octet-stream');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'imagen',
          _imagenBytes!,
          filename: filename,
          contentType: mediaType,
        ),
      );

      debugPrint('POST $url');
      debugPrint(
          'Campos: nombre=${request.fields['nombre']}, cantidad=${request.fields['cantidad']}, precio=${request.fields['precio']}, precioUnitario=${request.fields['precioUnitario']}');
      debugPrint(
          'Archivo: $filename (${_imagenBytes!.lengthInBytes} bytes), contentType=$mediaType');

      final streamed = await request.send();
      final responseBody = await http.Response.fromStream(streamed);
      debugPrint('Respuesta: ${streamed.statusCode} ${responseBody.body}');

      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        _mostrarAlerta("Producto registrado exitosamente", success: true);
        limpiarFormulario();
      } else if (streamed.statusCode == 401) {
        _mostrarAlerta('No autorizado. Inicia sesión nuevamente.',
            success: false);
      } else {
        _mostrarAlerta(
            'Error al registrar producto (${streamed.statusCode}): ${responseBody.body}',
            success: false);
      }
    } catch (e) {
      _mostrarAlerta('Error de red: $e', success: false);
    }
  }

  void limpiarFormulario() {
    setState(() {
      _nombreController.clear();
      _cantidadController.clear();
      _precioController.clear();
      _precioUnitarioController.clear();
      _imagenBytes = null;
      _imagenNombre = null;
    });
  }

  void _mostrarAlerta(String mensaje, {required bool success}) {
    Flushbar(
      message: mensaje,
      backgroundColor: success ? const Color(0xFFF26AB6) : Colors.redAccent,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      icon: Icon(
        success ? Icons.check_circle : Icons.error,
        color: Colors.white,
        size: 28,
      ),
      duration: const Duration(seconds: 3),
    ).show(context);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    _precioUnitarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Franja degradada decorativa arriba del logo
                      Center(
                        child: Container(
                          width: 140,
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Logo arriba del título "Agregar Producto"
                      Center(
                        child: Image.asset(
                          'assets/images/Logo.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Agregar Producto",
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildTextField(
                        _nombreController,
                        'Nombre del producto',
                        icon: Icons.label,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        _cantidadController,
                        'Cantidad',
                        icon: Icons.inventory,
                        isNumber: true,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        _precioController,
                        'Precio',
                        icon: Icons.attach_money,
                        isDecimal: true,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        _precioUnitarioController,
                        'Precio Unitario',
                        icon: Icons.monetization_on,
                        isDecimal: true,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 180,
                          width: double.infinity,
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
                          child: _imagenBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.memory(
                                    _imagenBytes!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Center(
                                      child:
                                          Icon(Icons.error, color: Colors.red),
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image,
                                      size: 50,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Selecciona una imagen',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _guardarProducto,
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
                                colors: gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              constraints: const BoxConstraints(minHeight: 50),
                              child: Text(
                                'Guardar Producto',
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
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 65,
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
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
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, bool isDecimal = false, IconData? icon}) {
    return Container(
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
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.poppins(),
        keyboardType: isDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : isNumber
                ? TextInputType.number
                : TextInputType.text,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          prefixIcon:
              icon != null ? Icon(icon, color: const Color(0xFFF26AB6)) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFF26AB6), width: 1.5),
          ),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Campo requerido' : null,
      ),
    );
  }
}
