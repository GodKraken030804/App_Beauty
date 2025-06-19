import 'package:flutter/material.dart';
import 'package:app_beauty/src/views/widgets/bottom_icon.dart';

class VistaPrueba extends StatelessWidget {
  const VistaPrueba({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Logo en la parte superior
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 120,
                ),
              ),
            ),

            // Espacio blanco para contenido futuro
            const Expanded(
              child: SizedBox(),
            ),

            // Footer con navegación
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
                    label: 'Mi perfil',
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
