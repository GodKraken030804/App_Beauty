import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OptionsView extends StatelessWidget {
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Column(
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            child: Column(
              children: [
                Image.asset('assets/images/Logo.png', height: 250), // Usa tu logo aquí
              ],
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
                  icon: Icons.person_add,
                  label: 'Inscripción De Alumnas',
                  onTap: () {
                    // Navegar a vista de inscripción
                  },
                ),
                MenuButton(
                  icon: Icons.verified_user_outlined,
                  label: 'Acceso De Alumnas',
                  onTap: () {
                    // Navegar a vista de acceso
                  },
                ),
                MenuButton(
                  icon: Icons.shopping_cart,
                  label: 'Ventas',
                  onTap: () {
                    // Navegar a vista de ventas
                  },
                ),
                MenuButton(
                  icon: Icons.inventory,
                  label: 'Inventario',
                  onTap: () {
                    // Navegar a vista de inventario
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
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                BottomIcon(icon: Icons.home, label: "Principal"),
                BottomIcon(icon: Icons.person, label: "Mi Perfil"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------
// Botón animado personalizado
// ------------------------------
class MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const MenuButton({required this.icon, required this.label, required this.onTap, Key? key}) : super(key: key);

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> with SingleTickerProviderStateMixin {
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
              Icon(widget.icon, color: Colors.white, size: 50),
              const SizedBox(height: 10),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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

  const BottomIcon({required this.icon, required this.label, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
