import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'options_view.dart'; // Para navegar a Principal

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

  @override
  void initState() {
    super.initState();
    _cargarImagen();
  }

  Future<void> _cargarImagen() async {
    final prefs = await SharedPreferences.getInstance();
    final imagenBase64 = prefs.getString('imagen_perfil');
    if (imagenBase64 != null && kIsWeb) {
      setState(() {
        _webImage = base64Decode(imagenBase64);
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
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await _guardarImagen(bytes);
        setState(() {
          _webImage = bytes;
          _mobileImage = null;
        });
      } else {
        setState(() {
          _mobileImage = File(image.path);
          _webImage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double avatarRadius = screenSize.width * 0.18;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 10),
              child: Image.asset(
                'assets/images/Logo.png',
                height: screenSize.height * 0.13,
              ),
            ),

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
                        ? Icon(Icons.person, size: avatarRadius, color: Colors.white)
                        : null,
                  ),
                  CircleAvatar(
                    radius: avatarRadius * 0.25,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.add, size: 20, color: Color(0xFFAA57EC)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Andrés Guízar Gómez',
              style: TextStyle(
                color: Color(0xFFAA57EC),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 30),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Gastos en desarrollo")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.attach_money),
                label: const Text(
                  'Gastos',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
              ),
              child: const Center(
                child: Text(
                  'Ingresos Totales',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const Spacer(),

            InkWell(
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/home');
              },
              child: const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Cerrar Sesión ⤿',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),

      // Footer con barra inferior igual a options_view.dart
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: SizedBox(
          height: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OptionsView()),
                  );
                },
                child: const BottomIcon(icon: Icons.home, label: "Principal"),
              ),
              GestureDetector(
                onTap: () {
                  // Ya estás aquí
                },
                child: const BottomIcon(icon: Icons.person, label: "Mi Perfil"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Icono reutilizable inferior (igual que en options_view)
class BottomIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const BottomIcon({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
