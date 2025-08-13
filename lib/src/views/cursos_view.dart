import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class CursosView extends StatefulWidget {
  const CursosView({super.key});

  @override
  State<CursosView> createState() => _CursosViewState();
}

class _CursosViewState extends State<CursosView> {
  List cursos = [];
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  @override
  void initState() {
    super.initState();
    _fetchCursos();
  }

  Future<void> _fetchCursos() async {
    final url = Uri.parse('${dotenv.env['API_EMPRESA']!.trim()}api/v1/curso');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          cursos = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Manejo de error opcional
    }
  }

  String _formatearFecha(String fecha) {
    final date = DateTime.tryParse(fecha);
    if (date == null) return fecha;
    final meses = [
      "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
      "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ];
    return "${date.day} De ${meses[date.month - 1]} De ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/Logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Cursos",
                    style: TextStyle(
                      color: gradientStart,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...cursos.map((curso) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [gradientStart, gradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.apartment, color: Colors.white, size: 40),
                        title: Text(
                          curso['nombre'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ciudad: ${curso['ciudad'] ?? ''}",
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            Text(
                              "Fecha De Inicio: ${_formatearFecha(curso['fecha_inicial'] ?? '')}",
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            Text(
                              "Fecha De Fin: ${_formatearFecha(curso['fecha_final'] ?? '')}",
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.apartment, color: Colors.white, size: 40),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        tileColor: Colors.transparent,
                      ),
                    ),
                  )),
                  if (cursos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "No hay cursos registrados.",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
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
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
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