import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  Future<void> _verificarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // ✅ clave correcta


    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/options'); // SI ya hay token → options
    } else {
      Navigator.pushReplacementNamed(context, '/home'); // SIN token → home
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _verificarSesion(context),
              child: Image.asset(
                'assets/images/Logo.png',
                width: 250,
                height: 250,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Toca el logo para continuar',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}