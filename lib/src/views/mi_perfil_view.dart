import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'options_view.dart';
import 'gastos_view.dart';
import 'Login_View.dart';
import 'ingresos_view.dart';

class MiPerfilView extends StatefulWidget {
  const MiPerfilView({super.key});

  @override
  State<MiPerfilView> createState() => _MiPerfilViewState();
}

class _MiPerfilViewState extends State<MiPerfilView> {
  Uint8List? _webImage;
  File? _mobileImage;
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);
  String _displayName = '';
  String _userType = '';

  @override
  void initState() {
    super.initState();
    _cargarImagen();
    _cargarNombre();
  }

  Future<void> _cargarImagen() async {
    final prefs = await SharedPreferences.getInstance();
    final imagenBase64 = prefs.getString('imagen_perfil');
    if (imagenBase64 != null) {
      setState(() {
        _webImage = base64Decode(imagenBase64);
      });
    }
  }

  Future<void> _guardarImagen(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('imagen_perfil', base64Encode(bytes));
  }

  Future<void> _cargarNombre() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    String resolved = '';
    String roleResolved = '';
    if (token != null && token.isNotEmpty) {
      try {
        final payload = JwtDecoder.decode(token);
        // Preferir 'nombre'; si está vacío, probar otros campos comunes
        final candidates = [
          'nombre',
          'name',
          'usuario',
          'fullName',
          'nombreCompleto',
        ];
        for (final k in candidates) {
          final v = payload[k];
          if (v != null && v.toString().trim().isNotEmpty) {
            resolved = v.toString().trim();
            break;
          }
        }

        // Rol/tipo del usuario
        final rawRole = (payload['rol'] ?? payload['usuario'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        switch (rawRole) {
          case 'admin':
            roleResolved = 'Administrador';
            break;
          case 'encargado':
            roleResolved = 'Encargado';
            break;
          case 'pedido':
            roleResolved = 'Pedido';
            break;
          default:
            roleResolved = 'Usuario';
        }
      } catch (_) {
        // If decoding fails, fall back to email/default below
      }
    }

    if (resolved.isEmpty) {
      resolved = 'Usuario';
    }

    if (mounted) {
      setState(() {
        _displayName = resolved;
        _userType = roleResolved.isNotEmpty ? roleResolved : 'Usuario';
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      await _guardarImagen(bytes);
      setState(() {
        if (kIsWeb) {
          _webImage = bytes;
          _mobileImage = null;
        } else {
          _mobileImage = File(image.path);
          _webImage = null;
        }
      });
      Flushbar(
        margin: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(15),
        backgroundColor: gradientStart,
        flushbarPosition: FlushbarPosition.TOP,
        icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
        titleText: Text(
          "Imagen cargada",
          style: GoogleFonts.poppins(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        messageText: Text(
          "La imagen de perfil se ha guardado correctamente.",
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
        animationDuration: const Duration(milliseconds: 500),
      ).show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double avatarRadius = screenSize.width * 0.18;
    final double topBarHeight = MediaQuery.of(context).padding.top + 60;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Stack(
        children: [
          // Gradient flush to very top including status bar space
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: topBarHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradientStart, gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  SizedBox(height: 60 + 20), // space below gradient bar
              Container(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: SizedBox(
                  height: 180,
                  child: Image.asset(
                    'assets/images/Logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
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
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _webImage != null
                                ? MemoryImage(_webImage!)
                                : _mobileImage != null
                                    ? FileImage(_mobileImage!) as ImageProvider
                                    : null,
                            child: (_webImage == null && _mobileImage == null)
                                ? Icon(Icons.person,
                                    size: avatarRadius, color: Colors.white)
                                : null,
                          ),
                          CircleAvatar(
                            radius: avatarRadius * 0.25,
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.add,
                                size: 20, color: Color(0xFFAA57EC)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _displayName,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userType,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const GastosView()),
                          );
                        },
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
                              colors: [gradientStart, gradientEnd],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(minHeight: 50),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.attach_money, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Gastos',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const IngresosView()),
                          );
                        },
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
                              colors: [gradientStart, gradientEnd],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(minHeight: 50),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.trending_up, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Ingresos adicionales',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginView()),
                        );
                      },
                      child: Text(
                        'Cerrar Sesión ⤿',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
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
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OptionsView()),
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
}
