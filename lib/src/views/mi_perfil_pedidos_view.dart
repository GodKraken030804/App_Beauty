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
import 'pedido_view.dart';
import 'Login_View.dart';

class MiPerfilPedidosView extends StatefulWidget {
  const MiPerfilPedidosView({super.key});

  @override
  State<MiPerfilPedidosView> createState() => _MiPerfilPedidosViewState();
}

class _MiPerfilPedidosViewState extends State<MiPerfilPedidosView> {
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
        // Preferir 'nombre' y luego otros posibles campos
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
        // Rol del usuario
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
      } catch (_) {}
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

  void _mostrarNotificacionPedidos(BuildContext context) {
    Flushbar(
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(15),
      backgroundColor: gradientStart,
      flushbarPosition: FlushbarPosition.TOP,
      icon: const Icon(Icons.info, color: Colors.white, size: 28),
      titleText: Text(
        'Ventas Pedidos',
        style: GoogleFonts.poppins(
          fontSize: 20,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      messageText: Text(
        'Consulta y gestiona tus ventas desde la pantalla Principal.',
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
                    // Acción destacada con el mismo estilo de botones (estética uniforme)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _mostrarNotificacionPedidos(context),
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
                              'Ventas Pedidos',
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
                    const SizedBox(height: 12),
                    // Divider visual para mantener proporciones con otras vistas
                    Container(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 12),
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
        child: SizedBox(
          height: 70,
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            currentIndex: 1,
            onTap: (index) {
              if (index == 0) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const PedidoView()),
                );
              }
            },
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
