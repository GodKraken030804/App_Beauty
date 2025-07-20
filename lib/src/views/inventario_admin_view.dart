import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class InventarioView extends StatefulWidget {
  const InventarioView({super.key});

  @override
  State<InventarioView> createState() => _InventarioViewState();
}

class _InventarioViewState extends State<InventarioView> {
  List productos = [];
  List encargados = [];
  List historial = [];
  List productosFiltrados = [];

  final List<Color> gradientColors = const [Color(0xFFF26AB6), Color(0xFFAA57EC)];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProductos();
    _fetchEncargados();
  }
  Future<void> _fetchProductos() async {
    final uri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/producto');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        setState(() {
          productos = jsonDecode(response.body);
          productosFiltrados = productos;
        });
        debugPrint(productos.toString()); // Imprime en consola la variable productos
      }
    } catch (e) {
      debugPrint('Error al obtener productos: $e');
    }
  }

  Future<void> _fetchEncargados() async {
    final uri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/usuario');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          encargados = data.where((u) => u['rol'] == 'encargado').toList();
        });
        debugPrint(encargados.toString()); // Imprime en consola la variable encargados
      }
    } catch (e) {
      debugPrint('Error al obtener encargados: $e');
    }
  }

  void _actualizarBusqueda(String query) {
    setState(() {
      productosFiltrados = productos.where((p) =>
        p['nombre'].toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  Widget _botonGradiente(String texto, VoidCallback onPressed, {IconData? icon, bool pequeno = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: pequeno
            ? const EdgeInsets.symmetric(vertical: 8, horizontal: 16)
            : const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              texto,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFlush(String mensaje, IconData icono, Color color) {
    Flushbar(
      message: mensaje,
      icon: Icon(icono, color: Colors.white),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }
  void _mostrarInputLlegoPedido(Map producto) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("¿Cuántas piezas llegaron?"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Cantidad',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          _botonGradiente("Cancelar", () => Navigator.pop(context), pequeno: true),
          _botonGradiente("Aceptar", () async {
            final cantidad = int.tryParse(controller.text);
            if (cantidad != null) {
              final confirmado = await _mostrarConfirmacion("¿Deseas actualizar el stock?");
              if (!confirmado) return;

              final payload = {
                'iduser': 1, // Reemplazar por ID real del usuario logueado
                'idproduc': producto['id'],
                'cantidad': cantidad
              };

              await http.post(
                Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/asignado'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              );

              setState(() {
                producto['cantidad'] += cantidad;
                historial.add({
                  'tipo': 'Pedido',
                  'producto': producto['nombre'],
                  'cantidad': cantidad,
                  'fecha': DateTime.now().toString(),
                });
              });

              Navigator.pop(context); // Cierra el formulario
              _mostrarFlush("Stock actualizado", Icons.check_circle, Colors.green);
            }
          }),
        ],
      ),
    );
  }

  Future<bool> _mostrarConfirmacion(String mensaje) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirmar"),
            content: Text(mensaje),
            actions: [
              _botonGradiente("No", () => Navigator.pop(context, false), pequeno: true),
              _botonGradiente("Sí", () => Navigator.pop(context, true), pequeno: true),
            ],
          ),
        ) ??
        false;
  }
  void _abrirDialogoProducto(Map producto) {
    showDialog(
      context: context,
      builder: (context) {
        String cantidadAsignar = '';
        dynamic encargadoSeleccionado;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/Logo.png', width: 200, height: 100),
                const SizedBox(height: 20),

                _botonGradiente("Llegó Pedido", () => _mostrarInputLlegoPedido(producto), icon: Icons.inventory_2),

                _botonGradiente("Asignar Productos", () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Asignar Productos'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField(
                              decoration: const InputDecoration(labelText: 'Selecciona un encargado'),
                              items: encargados.map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text(e['gmail']),
                                );
                              }).toList(),
                              onChanged: (value) {
                                encargadoSeleccionado = value;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Cantidad a asignar'),
                              onChanged: (value) => cantidadAsignar = value,
                            ),
                          ],
                        ),
                        actions: [
                          _botonGradiente("Cancelar", () => Navigator.pop(context), pequeno: true),
                          _botonGradiente("Asignar", () async {
                            final cantidad = int.tryParse(cantidadAsignar);
                            if (encargadoSeleccionado != null && cantidad != null) {
                              final confirmado = await _mostrarConfirmacion("¿Deseas asignar este producto?");
                              if (!confirmado) return;

                              // Historial local
                              setState(() {
                                historial.add({
                                  'tipo': 'Asignación',
                                  'producto': producto['nombre'],
                                  'cantidad': cantidad,
                                  'fecha': DateTime.now().toString(),
                                  'asignadoA': encargadoSeleccionado['gmail']
                                });
                              });

                              // Asignación de unidades (actualización de cantidad)
                              await http.post(
                                Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/asignado'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'iduser': encargadoSeleccionado['id'],
                                  'idproduc': producto['id'],
                                  'cantidad': cantidad,
                                }),
                              );

                              // Relación iduser-idproduc-cantidad
                            

                              Navigator.pop(context); // cerrar modal asignar
                              Navigator.pop(context); // cerrar modal producto
                              

                              _mostrarFlush("Producto asignado correctamente", Icons.assignment_turned_in, Colors.blue);
                            }
                          }),
                        ],
                      );
                    },
                  );
                }, icon: Icons.assignment_ind),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> _exportarHistorialExcel() async {
    final archivoExcel = excel.Excel.createExcel();
    final sheet = archivoExcel['Historial'];
    sheet.appendRow(['Tipo', 'Producto', 'Cantidad', 'Fecha', 'Asignado A']);

    for (var mov in historial) {
      sheet.appendRow([
        mov['tipo'],
        mov['producto'],
        mov['cantidad'].toString(),
        mov['fecha'],
        mov['asignadoA'] ?? '',
      ]);
    }
    

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/historial_app_beauty.xlsx';
    final file = File(path);
    file.writeAsBytesSync(archivoExcel.encode()!);

    await Share.shareXFiles([XFile(path)], text: 'Historial App Beauty');
  }

  Future<void> _exportarExcel() async {
  final archivoExcel = excel.Excel.createExcel();
  final sheet = archivoExcel['Inventario'];
  sheet.appendRow(['Nombre', 'Cantidad']);
  for (var p in productos) {
    sheet.appendRow([p['nombre'], p['cantidad']]);
  }

  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/inventario.xlsx';
  final file = File(path);
  file.writeAsBytesSync(archivoExcel.encode()!);

  await Share.shareXFiles([XFile(path)], text: 'Inventario App Beauty');
}


  void _mostrarHistorial() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: _botonGradiente("Exportar Historial", _exportarHistorialExcel, icon: Icons.file_download),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: historial.reversed.map((mov) {
                return ListTile(
                  leading: Icon(
                    mov['tipo'] == 'Pedido' ? Icons.add : Icons.assignment_ind,
                    color: mov['tipo'] == 'Pedido' ? Colors.green : Colors.blue,
                  ),
                  title: Text("${mov['tipo']} de ${mov['cantidad']} unidades"),
                  subtitle: Text("${mov['producto']} - ${mov['fecha'].toString().split('.')[0]}"),
                  trailing: mov['asignadoA'] != null ? Text(mov['asignadoA']) : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'historial',
            backgroundColor: const Color(0xFFAA57EC),
            onPressed: _mostrarHistorial,
            child: const Icon(Icons.history),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'exportar',
            backgroundColor: const Color(0xFFF26AB6),
            onPressed: _exportarExcel,
            child: const Icon(Icons.file_download),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
        ),
        child: BottomNavigationBar(
          onTap: (index) {
            if (index == 0);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Principal"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Mi Perfil"),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Image.asset('assets/images/Logo.png', width: 200, height: 100),
              const SizedBox(height: 10),
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: "Buscar producto...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                onChanged: _actualizarBusqueda,
              ),
              const SizedBox(height: 10),
              const Text("Inventario General", style: TextStyle(color: Colors.purple, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: productosFiltrados.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (context, index) {
                  final producto = productosFiltrados[index];
                  final imagenNombre = (producto['imagen'] ?? '').toString().split('/').last;
                  final imagenUrl = "${dotenv.env['API_GATEWAY']}imagenes/$imagenNombre";
                  final cantidad = producto['cantidad'] ?? 0;

                  return GestureDetector(
                    onTap: () => _abrirDialogoProducto(producto),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: cantidad < 10 ? Border.all(color: Colors.red, width: 2) : null,
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
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
