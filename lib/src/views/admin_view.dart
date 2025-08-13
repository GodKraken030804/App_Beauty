import 'package:flutter/material.dart';
import 'package:app_beauty/src/views/agregar_producto_view.dart';
import 'package:app_beauty/src/views/inventario_admin_view.dart';
import 'package:app_beauty/src/views/crear_curso_view.dart';
import 'package:app_beauty/src/views/cursos_view.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  int _currentIndex = 0;

  void _onPressed(String section) {
    Widget? destino;

    switch (section) {
      case "Inventario":
         destino = const InventarioView();
        break;
      case "Creación De Curso":
        destino = const CrearCursoView();
        break;
      case "Administrar Cursos":
        destino = const CursosView();
        break;
      case "Administrar Encargados":
        // destino = const AdminEncargadosView();
        break;
      case "Agregar Producto":
        destino = const AgregarProductoView();
        break;
      case "Historiales":
        // destino = const HistorialesView();
        break;
    }

    if (destino != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destino!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const gradientColors = [Color(0xFFF26AB6), Color(0xFFAA57EC)];

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Image.asset(
                'assets/images/Logo.png',
                width: 280,
                height: 280,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildWrapButton("Inventario", Icons.inventory),
                  _buildWrapButton("Creación De Curso", Icons.create),
                  _buildWrapButton("Administrar Cursos", Icons.menu_book),
                  _buildWrapButton("Administrar Encargados", Icons.people),
                  _buildWrapButton("Agregar Producto", Icons.add_box),
                ],
              ),

              const SizedBox(height: 50),

              // Botón horizontal "Historiales"
              SizedBox(
                width: double.infinity,
                height: 80,
                child: InkWell(
                  onTap: () => _onPressed("Historiales"),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.history, color: Colors.white, size: 30),
                        SizedBox(width: 10),
                        Text(
                          "Historiales",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // BottomNavigationBar con degradado
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          onTap: (index) {
            setState(() => _currentIndex = index);
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
    );
  }

  Widget _buildWrapButton(String label, IconData icon) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      height: 120,
      child: _buildButton(icon, label, () => _onPressed(label)),
    );
  }

  Widget _buildButton(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
