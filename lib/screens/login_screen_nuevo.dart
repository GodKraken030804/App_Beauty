import 'package:flutter/material.dart';

class LoginScreenNuevo extends StatelessWidget {
  const LoginScreenNuevo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFF8BBD0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', width: 150),
                const SizedBox(height: 20),
                const Text(
                  'Hola,\nBienvenida De Nuevo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    children: [
                      Image.asset('assets/images/logo.png', width: 80),
                      const SizedBox(height: 20),
                      _buildInputField(
                          'Correo Electrónico', 'ejemplo@correo.com'),
                      const SizedBox(height: 15),
                      _buildInputField('Contraseña', '********',
                          isPassword: true),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {},
                        child: const Text('¿Has Olvidado Tu Contraseña?'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.person, color: Colors.white),
                        label: const Text('Iniciar Sesión',
                            style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint,
      {bool isPassword = false}) {
    return TextField(
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
      ),
    );
  }
}
