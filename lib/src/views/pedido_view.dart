import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:app_beauty/src/views/inventario_view.dart';
// import 'package:app_beauty/src/views/ventas_view.dart';
import 'package:app_beauty/src/views/pedidos_ventas_view.dart';
import 'package:app_beauty/src/views/mi_perfil_pedidos_view.dart';

class PedidoView extends StatefulWidget {
  const PedidoView({super.key});

  @override
  State<PedidoView> createState() => _PedidoViewState();
}

class _PedidoViewState extends State<PedidoView> {
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
            // Dos botones para Inventario y Ventas
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.65,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MenuButton(
                    imageAsset: 'assets/images/inventario.png',
                    label: 'Inventario',
                    gradientStart: gradientStart,
                    gradientEnd: gradientEnd,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProductosExcelView(
                                  pedidoMode: true,
                                )),
                      );
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
                        MaterialPageRoute(
                            builder: (_) => const VentasPedidosView()),
                      );
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
        child: SafeArea(
          child: SizedBox(
            height: 65,
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                if (index == 0) {
                  // Forzar navegación a PedidoView para mantener circuito entre 2 vistas
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PedidoView()),
                  );
                } else if (index == 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MiPerfilPedidosView()),
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
