import 'package:flutter/material.dart';

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
              
              // Logo Beauty Creators (reemplaza el texto)
              Image.asset(
                'assets/images/Logo.png', // Asegúrate de tener este archivo
                width: 350,
                height: 220,
                fit: BoxFit.contain,
              ),
              
              const Spacer(),

              // Barra inferior con botón integrado
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 195, 19, 142).withOpacity(0.9),
                ),
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(245, 0, 228, 1),
                        foregroundColor: const Color.fromARGB(255, 253, 253, 253),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 3,
                      ),
                      child: const Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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