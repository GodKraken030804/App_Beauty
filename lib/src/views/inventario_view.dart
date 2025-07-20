import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProductosExcelView extends StatefulWidget {
  const ProductosExcelView({super.key});

  @override
  State<ProductosExcelView> createState() => _ProductosExcelViewState();
}

class _ProductosExcelViewState extends State<ProductosExcelView> {
  List productosAsignados = [];
  final List<Color> gradientColors = const [Color(0xFFF26AB6), Color(0xFFAA57EC)];

  @override
  void initState() {
    super.initState();
    _fetchProductosAsignados();
  }

  Future<void> _fetchProductosAsignados() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final userId = JwtDecoder.decode(token)['id'];
    final asignadoUri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/asignado');
    final productoUri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/producto');

    try {
      final asignadoRes = await http.get(asignadoUri);
      final productoRes = await http.get(productoUri);

      if (asignadoRes.statusCode == 200 && productoRes.statusCode == 200) {
        final asignaciones = jsonDecode(asignadoRes.body);
        final productosAll = jsonDecode(productoRes.body);

        final asignadosUsuario = asignaciones.where((a) => a['iduser'] == userId).toList();
        final Map<int, dynamic> productosAgrupados = {};

        for (var a in asignadosUsuario) {
          final producto = productosAll.firstWhere((p) => p['id'] == a['idproduc'], orElse: () => null);
          if (producto != null) {
            final pid = producto['id'];
            if (productosAgrupados.containsKey(pid)) {
              productosAgrupados[pid]['cantidad_asignada'] += a['cantidad'];
            } else {
              final nuevo = Map<String, dynamic>.from(producto);
              nuevo['cantidad_asignada'] = a['cantidad'];
              productosAgrupados[pid] = nuevo;
            }
          }
        }

        setState(() {
          productosAsignados = productosAgrupados.values.toList();
        });
      }
    } catch (e) {
      debugPrint('Error al cargar productos asignados: $e');
    }
  }

  Widget _botonGradiente(String texto, VoidCallback onPressed, {IconData? icon}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: const Text("Productos Asignados", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFAA57EC),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: productosAsignados.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                itemCount: productosAsignados.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (context, index) {
                  final producto = productosAsignados[index];
                  final imagenNombre = (producto['imagen'] ?? '').toString().split('/').last;
                  final imagenUrl = "${dotenv.env['API_GATEWAY']}imagenes/$imagenNombre";
                  final cantidad = producto['cantidad_asignada'] ?? 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imagenUrl,
                            height: 80,
                            width: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.broken_image, size: 80, color: Colors.grey);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          producto['nombre'] ?? '',
                          style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradientColors),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "$cantidad",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              const Text("Unidades", style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'historial',
            backgroundColor: const Color(0xFFAA57EC),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Aquí se mostrará el historial", style: TextStyle(fontSize: 16)),
                ),
              );
            },
            child: const Icon(Icons.history),
          ),
        ],
      ),
    );
  }
}
