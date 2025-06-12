import 'package:flutter/material.dart';
import 'package:app_beauty/src/views/splash_view.dart';
import 'package:app_beauty/src/views/home_view.dart';
import 'package:app_beauty/src/views/Login_View.dart';
import 'package:app_beauty/src/views/options_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Beauty',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashView(), // Splash como pantalla inicial
      routes: {
        '/home': (context) => const HomeView(), // Ruta para Home

        '/login': (context) => LoginView(), // Ruta para Login

        '/options': (context) => OptionsView(), // Ruta para Opciones
      },
    );
  }
}
