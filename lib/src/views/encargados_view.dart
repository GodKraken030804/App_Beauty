import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_beauty/src/views/admin_view.dart';
import 'package:app_beauty/src/views/mi_perfil_admin.dart';

class EncargadosView extends StatefulWidget {
  const EncargadosView({super.key});

  @override
  State<EncargadosView> createState() => _EncargadosViewState();
}

class _EncargadosViewState extends State<EncargadosView> {
  final List<Color> gradientColors = const [
    Color(0xFFF26AB6),
    Color(0xFFAA57EC),
  ];

  Future<List<String>> _fetchEncargados() async {
    final url = Uri.parse('${dotenv.env['API_EMPRESA']!.trim()}api/v1/usuario');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data as List)
          .where((u) => (u['usuario']?.toLowerCase() == 'encargado'))
          .map<String>((u) => (u['nombre']?.toString() ?? ''))
          .where((nombre) => nombre.isNotEmpty)
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Column(
        children: [
          // Barra superior con degradado
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
          const SizedBox(height: 8),
          // Encabezado con logo y título
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/Logo.png',
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Encargados',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: gradientColors.first,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _fetchEncargados(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child:
                        Text('No hay encargados', style: GoogleFonts.poppins()),
                  );
                }

                final encargados = snapshot.data!;

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: encargados.length,
                  itemBuilder: (context, index) {
                    final nombre = encargados[index];
                    return _EncargadoTile(
                        nombre: nombre, gradientColors: gradientColors);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
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
      ),
    );
  }
}

class _EncargadoTile extends StatefulWidget {
  final String nombre;
  final List<Color> gradientColors;
  const _EncargadoTile(
      {Key? key, required this.nombre, required this.gradientColors})
      : super(key: key);

  @override
  State<_EncargadoTile> createState() => _EncargadoTileState();
}

class _EncargadoTileState extends State<_EncargadoTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 8, offset: Offset(2, 4)),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person,
                      color: widget.gradientColors.first, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.nombre,
                    style: GoogleFonts.poppins(
                      color: widget.gradientColors.first,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
