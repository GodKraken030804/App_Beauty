import 'package:flutter/material.dart';
import 'package:app_beauty/src/views/splash_view.dart';
import 'package:app_beauty/src/views/home_view.dart';
import 'package:app_beauty/src/views/Login_View.dart';
import 'package:app_beauty/src/views/options_view.dart';
import 'package:app_beauty/src/views/inventario_view.dart';
import 'package:app_beauty/src/views/mi_perfil_view.dart';
import 'package:app_beauty/src/views/admin_view.dart';

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
        '/home': (context) => const HomeView(),
        '/perfil': (context) => const MiPerfilView(),
        '/login': (context) => const LoginView(),
        '/options': (context) => const OptionsView(),
        '/inventario': (context) => const ProductosExcelView(),
        '/administrador': (context) => const AdminView(),
      },
    );
  }
}
