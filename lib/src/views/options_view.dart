import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:app_beauty/src/views/inventario_view.dart';
import 'package:app_beauty/src/views/ventas_view.dart';
import 'registro_alumnas_view.dart';
import 'package:app_beauty/src/views/mi_perfil_view.dart';
import 'package:app_beauty/src/views/cursos_administradores_view.dart';

class OptionsView extends StatefulWidget {
  const OptionsView({super.key});

  @override
  State<OptionsView> createState() => _OptionsViewState();
}

class _OptionsViewState extends State<OptionsView> {
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _verificarYMostrarNotificacion();
  }

  Future<void> _verificarYMostrarNotificacion() async {
    final prefs = await SharedPreferences.getInstance();
    final yaMostrado = prefs.getBool('notificacion_mostrada') ?? false;

    if (!yaMostrado) {
      await prefs.setBool('notificacion_mostrada', true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarNotificacionExitosa(context);
      });
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

  @override
  Widget build(BuildContext context) {
    // final size = MediaQuery.of(context).size; // No utilizado actualmente

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.only(top: 20, bottom: 4),
              child: SizedBox(
                height: 180,
                child: Image.asset(
                  'assets/images/Logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Cuatro botones
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.65, // más alto (~+30%)
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MenuButton(
                    imageAsset: 'assets/images/inscripcion.png',
                    label: 'Inscribir Alumnas',
                    gradientStart: gradientStart,
                    gradientEnd: gradientEnd,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegistroAlumnasView()),
                      );
                    },
                  ),
                  MenuButton(
                    imageAsset: 'assets/images/acceso.png',
                    label: 'Acceso De Alumnas',
                    gradientStart: gradientStart,
                    gradientEnd: gradientEnd,
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CursosAdministradoresView(),
                          ));
                    },
                  ),
                  MenuButton(
                    imageAsset: 'assets/images/ventas.png',
                    label: 'Ventas',
                    gradientStart: gradientStart,
                    gradientEnd: gradientEnd,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VentasView()),
                      );
                    },
                  ),
                  MenuButton(
                    imageAsset: 'assets/images/inventario.png',
                    label: 'Inventario',
                    gradientStart: gradientStart,
                    gradientEnd: gradientEnd,
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProductosExcelView(),
                          ));
                    },
                  ),
                ],
              ),
            ),
          ],
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
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              if (index == 0) {
                // Ya estás en Principal, no hace nada
              } else if (index == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MiPerfilView()),
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
    );
  }
}

// ------------------------------
// Botón animado personalizado con imagen
// ------------------------------
class MenuButton extends StatelessWidget {
  final String imageAsset;
  final String label;
  final VoidCallback onTap;
  final Color gradientStart;
  final Color gradientEnd;

  const MenuButton({
    required this.imageAsset,
    required this.label,
    required this.gradientStart,
    required this.gradientEnd,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Replica exacta del estilo de Login_View: ElevatedButton + Ink con gradiente,
    // borde 15, elevación 5, ripple al presionar.
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(18),
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
          // sin minHeight fija para que el Grid pueda crecer
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(imageAsset, height: 108, fit: BoxFit.contain),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
