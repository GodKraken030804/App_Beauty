import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo de pantalla completa
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/diplexus_logo.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Contenido principal
          Column(
            children: [
              // Espacio superior
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),

              // Logo Beauty Creators
              Image.asset(
                'assets/images/Logo.png',
                width: 350,
                height: 220,
                fit: BoxFit.contain,
              ),

              const Spacer(),

              // Barra inferior con botón integrado
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color:
                      const Color.fromARGB(255, 195, 19, 142).withOpacity(0.9),
                ),
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: MenuButton(
                      icon: Icons.login,
                      label: 'Iniciar Sesión',
                      onTap: () {
                        Navigator.pushNamed(context, '/login');
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const MenuButton(
      {required this.icon, required this.label, required this.onTap, Key? key})
      : super(key: key);

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
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
