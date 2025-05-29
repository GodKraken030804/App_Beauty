import 'package:flutter/material.dart';

class HomeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inicio')),
      body: Center(child: Text('¡Hola Jorge Molina! Bienvenido a App Beauty')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Acción del botón flotante
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('¡Botón flotante presionado!')),
          );
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.pink,
      ),
    );
  }
}
