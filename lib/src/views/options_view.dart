import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:app_beauty/src/views/acceso_alumnas_view.dart';
import 'package:app_beauty/src/views/inventario_view.dart';
import 'registro_alumnas_view.dart';


class OptionsView extends StatefulWidget {
  const OptionsView({super.key});

  @override
  State<OptionsView> createState() => _OptionsViewState();
}

class _OptionsViewState extends State<OptionsView> {
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: SizedBox(
              height: 250,
              child: Image.asset(
                'assets/images/Logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Cuatro botones
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                MenuButton(
                  imageAsset: 'assets/images/inscripcion.png',
                  label: 'Inscripción De Alumnas',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegistroAlumnasView()),
                    );
                  },
                ),

                MenuButton(
                  imageAsset: 'assets/images/acceso.png',
                  label: 'Acceso De Alumnas',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const AccesoAlumnasView(),
                    ));
                  },
                ),
                MenuButton(
                  imageAsset: 'assets/images/ventas.png',
                  label: 'Ventas',
                  onTap: () {
                    // Navegar a vista de ventas
                  },
                ),
                MenuButton(
                  imageAsset: 'assets/images/inventario.png',
                  label: 'Inventario',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const ProductosExcelView(),
                    ));
                  },
                ),
              ],
            ),
          ),

          // Barra inferior
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientStart, gradientEnd],
              ),
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
                children: const [
                  BottomIcon(icon: Icons.home, label: "Principal"),
                  BottomIcon(icon: Icons.person, label: "Mi Perfil"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------
// Botón animado personalizado con imagen
// ------------------------------
class MenuButton extends StatefulWidget {
  final String imageAsset;
  final String label;
  final VoidCallback onTap;

  const MenuButton({
    required this.imageAsset,
    required this.label,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 0.05,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _controller.reverse,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(widget.imageAsset, height: 90, fit: BoxFit.contain),
              const SizedBox(height: 10),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------
// Ícono inferior personalizado
// ------------------------------
class BottomIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const BottomIcon({required this.icon, required this.label, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 45),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 22),
        ),
      ],
    );
  }
}