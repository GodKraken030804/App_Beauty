import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:app_beauty/src/views/agregar_producto_view.dart';
import 'package:app_beauty/src/views/inventario_admin_view.dart';
import 'package:app_beauty/src/views/crear_curso_view.dart';
import 'package:app_beauty/src/views/mi_perfil_admin.dart';
import 'package:app_beauty/src/views/asignacion_view.dart';
import 'package:app_beauty/src/views/asignaciones_view.dart';
import 'package:app_beauty/src/views/admin_inventarios_view.dart';
import 'package:app_beauty/src/views/gestion_usuarios_view.dart';
import 'cursos_view.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  int _currentIndex = 0;
  // Colores de la app para notificación
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  @override
  void initState() {
    super.initState();
    _verificarYMostrarNotificacion();
  }

  Future<void> _verificarYMostrarNotificacion() async {
    final prefs = await SharedPreferences.getInstance();
    // Usamos una clave distinta para Admin para que también se muestre al menos una vez en esta vista
    final yaMostrado = prefs.getBool('notificacion_admin_mostrada') ?? false;

    if (!yaMostrado) {
      await prefs.setBool('notificacion_admin_mostrada', true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarNotificacionBienvenida(context);
      });
    }
  }

  void _mostrarNotificacionBienvenida(BuildContext context) {
    Flushbar(
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(15),
      backgroundColor: gradientStart,
      flushbarPosition: FlushbarPosition.TOP,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
      titleText: const Text(
        "¡Bienvenido!",
        style: TextStyle(
            fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      messageText: const Text(
        "Inicio de sesión exitoso.",
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 500),
    ).show(context);
  }

  void _onPressed(String section) {
    Widget? destino;

    switch (section) {
      case "Inventario":
        destino = const InventarioView();
        break;
      case "Creación De Curso":
        destino = const CrearCursoView();
        break;
      case "Administrar Cursos":
        destino = const AsignacionesView();
        break;
      case "Consultar Inventarios":
        destino = const AdminInventariosView();
        break;
      case "Agregar Producto":
        destino = const AgregarProductoView();
        break;
      case "Asignación":
        destino = const AsignacionView();
        break;
      case "Ver Cursos":
        destino = const CursosView();
        break;
      case "Gestión de Usuarios":
        destino = const GestionUsuariosView();
        break;
    }

    if (destino != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destino!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const gradientColors = [Color(0xFFF26AB6), Color(0xFFAA57EC)];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: SizedBox(
                  height: 130,
                  child: Image.asset(
                    'assets/images/Logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Grid de opciones
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMenuButton("Inventario", Icons.inventory),
                  _buildMenuButton("Creación De Curso", Icons.create),
                  _buildMenuButton("Administrar Cursos", Icons.menu_book),
                  _buildMenuButton("Consultar Inventarios", Icons.inventory_2),
                  _buildMenuButton("Agregar Producto", Icons.add_box),
                  _buildMenuButton("Ver Cursos", Icons.school),
                  _buildMenuButton("Asignación", Icons.assignment_ind),
                  _buildMenuButton("Gestión de Usuarios", Icons.people),
                ],
              ),
            ],
          ),
        ),
      ),

      // BottomNavigationBar con esquinas redondeadas
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
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
              currentIndex: _currentIndex,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              type: BottomNavigationBarType.fixed,
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
        ),
      ),
    );
  }

  Widget _buildMenuButton(String label, IconData icon) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      child: ElevatedButton(
        onPressed: () => _onPressed(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
          shadowColor: Colors.grey.withOpacity(0.5),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 145),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 50, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
