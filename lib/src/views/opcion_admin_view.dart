import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:app_beauty/src/views/widgets/bottom_icon.dart';

class OpcionAdminView extends StatefulWidget {
  const OpcionAdminView({super.key});

  @override
  State<OpcionAdminView> createState() => _OpcionAdminViewState();
}

class _OpcionAdminViewState extends State<OpcionAdminView> {
  final Color gradientStart = const Color(0xFFF26AB6); // Rosa principal

  @override
  void initState() {
    super.initState();
    _verificarNotificacion();
  }

  Future<void> _verificarNotificacion() async {
    final prefs = await SharedPreferences.getInstance();
    final yaMostrada = prefs.getBool('notificacion_mostrada_opcion_admin') ?? false;

    if (!yaMostrada && mounted) {
      _mostrarNotificacionExitosa(context);
      await prefs.setBool('notificacion_mostrada_opcion_admin', true);
    }
  }

  void _mostrarNotificacionExitosa(BuildContext context) {
    Flushbar(
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(15),
      backgroundColor: gradientStart,
      flushbarPosition: FlushbarPosition.TOP,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
      titleText: const Text(
        "¡Bienvenido!",
        style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      messageText: const Text(
        "Inicio de sesión exitoso.",
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 500),
    ).show(context);
  }

  Widget _botonOpcion(String titulo, String imagen, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF26AB6), Color(0xFFFC9D45)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Image.asset('assets/$imagen', height: 60),
                const SizedBox(height: 10),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Logo superior
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 100,
                ),
              ),
            ),
            // Botones principales
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _botonOpcion('Inventario', 'inventario.png', () {
                          Navigator.pushNamed(context, '/inventario');
                        }),
                        _botonOpcion('Creación De Curso', 'creacioncurso.png', () {
                          // Acción personalizada
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _botonOpcion('Administrar Cursos', 'administrarcurso.png', () {
                          // Acción personalizada
                        }),
                        _botonOpcion('Administrar Encargados', 'administrarencargados.png', () {
                          // Acción personalizada
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _botonOpcion('Historiales', 'historiales.png', () {
                      // Acción personalizada
                    }),
                  ],
                ),
              ),
            ),
            // Footer fijo
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF26AB6), Color(0xFFFC9D45)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BottomIcon(
                    icon: Icons.home,
                    label: 'Principal',
                    onTap: () => Navigator.pushNamed(context, '/options'),
                  ),
                  BottomIcon(
                    icon: Icons.person,
                    label: 'Mi Perfil',
                    onTap: () => Navigator.pushNamed(context, '/perfil'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
