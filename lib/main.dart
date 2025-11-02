import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_beauty/src/views/splash_view.dart';
import 'package:app_beauty/src/views/home_view.dart';
import 'package:app_beauty/src/views/Login_View.dart';
import 'package:app_beauty/src/views/options_view.dart';
import 'package:app_beauty/src/views/inventario_view.dart';
import 'package:app_beauty/src/views/mi_perfil_view.dart';
import 'package:app_beauty/src/views/admin_view.dart';
import 'package:app_beauty/src/views/cursos_administradores_view.dart';
import 'package:app_beauty/src/views/acceso_alumnas_view.dart';
import 'package:app_beauty/src/views/gastos_cursos_view.dart';
import 'package:app_beauty/src/views/ventas_view.dart';
import 'package:app_beauty/src/views/pedido_view.dart';
import 'package:app_beauty/src/views/vista_prueba.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
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
      home: const SplashView(),
      routes: {
        '/home': (context) => const HomeView(),
        '/perfil': (context) => const MiPerfilView(),
        '/login': (context) => const LoginView(),
        '/options': (context) => const OptionsView(),
        '/inventario': (context) => const ProductosExcelView(),
        '/administrador': (context) => const AdminView(),
        '/pedido': (context) => const PedidoView(),
        '/cursos_administradores': (context) =>
            const CursosAdministradoresView(),
        '/acceso_alumnas': (context) => const AccesoAlumnasView(),
        '/gastos_cursos': (context) => const GastosCursosView(),
        '/ventas': (context) => const VentasView(),
        '/vista_prueba': (context) => const VistaPrueba(),
      },
    );
  }
}
