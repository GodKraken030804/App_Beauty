import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    // Ejecutar verificación justo después del primer frame para tener contexto listo
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarSesion());
  }

  Future<void> _verificarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // Si el token es válido, navegar según el rol
      try {
        final isExpired = JwtDecoder.isExpired(token);
        if (isExpired) {
          // Token expirado → limpiar y enviar a home/login
          await prefs.remove('token');
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }

        final payload = JwtDecoder.decode(token);
        final rol = payload['rol'] ?? 'default';
        if (rol == 'admin') {
          Navigator.pushReplacementNamed(context, '/administrador');
        } else {
          Navigator.pushReplacementNamed(context, '/options');
        }
      } catch (_) {
        // Si falla el decode, enviamos a opciones como fallback
        Navigator.pushReplacementNamed(context, '/options');
      }
    } else {
      // Sin token → mostrar home (pantalla de entrada)
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            // Logo
            Image(
              image: AssetImage('assets/images/Logo.png'),
              width: 250,
              height: 250,
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFFF26AB6)),
            SizedBox(height: 12),
            Text(
              'Iniciando…',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
