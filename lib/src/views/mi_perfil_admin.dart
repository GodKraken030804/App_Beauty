import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:app_beauty/src/views/admin_view.dart';
import 'package:app_beauty/src/views/Login_View.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:another_flushbar/flushbar.dart';

class MiPerfilAdmin extends StatefulWidget {
  const MiPerfilAdmin({super.key});

  @override
  State<MiPerfilAdmin> createState() => _MiPerfilAdminState();
}

class _MiPerfilAdminState extends State<MiPerfilAdmin> {
  Uint8List? _webImage;
  File? _mobileImage;
  String _nombre = "Administrador";
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final imagenBase64 = prefs.getString('imagen_perfil');
    final nombreGuardado = prefs.getString('nombre_admin');

    if (imagenBase64 != null) {
      final bytes = base64Decode(imagenBase64);
      setState(() {
        // Cargar siempre en memoria para que persista al volver
        _webImage = bytes; // Usaremos MemoryImage para mostrarla
        _mobileImage =
            null; // Evitar crear File desde bytes (no es una ruta válida)
      });
    }

    if (nombreGuardado != null) {
      setState(() {
        _nombre = nombreGuardado;
      });
    }
  }

  Future<void> _guardarImagen(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('imagen_perfil', base64Encode(bytes));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      await _guardarImagen(bytes);

      setState(() {
        // Mostrar siempre desde memoria para que al volver a la vista siga visible
        _webImage = bytes;
        _mobileImage = null;
      });
    }
  }

  void _mostrarNotificacionIngresos(BuildContext context) {
    Flushbar(
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(15),
      backgroundColor: gradientStart,
      flushbarPosition: FlushbarPosition.TOP,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
      titleText: Text(
        "Ingresos Totales",
        style: GoogleFonts.poppins(
          fontSize: 20,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      messageText: Text(
        "Ingresos Totales en Desarrollo.",
        style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
      ),
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 500),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double avatarRadius = screenSize.width * 0.18;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Top gradient bar for visual consistency
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Logo (misma estética que mi_perfil_view)
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
              // Card contenedor blanco con sombra
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
                    // Avatar editable
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
                    // Nombre
                    Text(
                      _nombre,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Ingresos Totales como botón con efecto y ripple (estilo Options_View)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _mostrarNotificacionIngresos(context),
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
                            child: Text(
                              'Ingresos Totales',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 12),
                    // Divider visual
                    Container(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    // Cerrar Sesión (restaurado)
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
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
              currentIndex: 1,
              onTap: (index) {
                if (index == 0) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminView()),
                    (route) => false,
                  );
                }
                // Si es 1, ya está en perfil, no hace nada
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
