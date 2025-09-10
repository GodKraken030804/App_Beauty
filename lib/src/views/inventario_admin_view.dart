import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_beauty/src/views/admin_view.dart';
import 'package:app_beauty/src/views/mi_perfil_admin.dart';
import 'package:image_picker/image_picker.dart';

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

  final List<Color> gradientColors = const [
    Color(0xFFF26AB6),
    Color(0xFFAA57EC)
  ];
  TextEditingController searchController = TextEditingController();
  int _currentIndex = 0; // Agrega esta línea para manejar el índice

  @override
  void initState() {
    super.initState();
    _fetchProductos();
    _fetchEncargados();
  }

  // Helper: Actualiza un producto por ID enviando todos los campos.
  // Si se proporciona imagenFile, se envía como multipart; de lo contrario, sólo campos.
  Future<bool> _actualizarProductoPorId({
    required int id,
    required String nombre,
    required int cantidad,
    required dynamic precio,
    File? imagenFile,
  }) async {
    final uri =
        Uri.parse("${dotenv.env['API_GATEWAY']}actualizar-producto/$id");
    try {
      final request = http.MultipartRequest('PUT', uri)
        ..fields['nombre'] = nombre
        ..fields['cantidad'] = cantidad.toString()
        ..fields['precio'] = precio.toString();

      if (imagenFile != null) {
        request.files
            .add(await http.MultipartFile.fromPath('imagen', imagenFile.path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint(
          'Fallo al actualizar producto ($id): ${response.statusCode} -> ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error al actualizar producto ($id): $e');
      return false;
    }
  }

  // Helper: Elimina un producto por ID en el API_GATEWAY
  Future<bool> _eliminarProductoPorId({required int id}) async {
    final uri = Uri.parse("${dotenv.env['API_GATEWAY']}eliminar-producto/$id");
    try {
      final response = await http.delete(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint(
          'Fallo al eliminar producto ($id): ${response.statusCode} -> ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error al eliminar producto ($id): $e');
      return false;
    }
  }

  // Diálogo para editar/actualizar un producto (nombre, cantidad, precio e imagen opcional)
  void _mostrarEditarProducto(Map producto) {
    final nombreCtrl =
        TextEditingController(text: producto['nombre']?.toString() ?? '');
    final cantidadCtrl =
        TextEditingController(text: (producto['cantidad'] ?? 0).toString());
    final precioCtrl =
        TextEditingController(text: producto['precio']?.toString() ?? '0');
    File? imagenFile;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) => Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabecera con degradado y título
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.edit, color: Colors.purple),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Editar producto',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contenido
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          labelStyle: const TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: gradientColors.last, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nombreCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              prefixIcon: Icon(Icons.label_outline),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: cantidadCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: precioCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Precio',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _botonGradiente('Seleccionar imagen', () async {
                                final picked = await ImagePicker()
                                    .pickImage(source: ImageSource.gallery);
                                if (picked != null) {
                                  setStateSB(
                                      () => imagenFile = File(picked.path));
                                }
                              }, icon: Icons.image, pequeno: true),
                              const SizedBox(width: 12),
                              if (imagenFile != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    imagenFile!,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                const Expanded(
                                  child: Text(
                                    'Imagen opcional',
                                    style: TextStyle(color: Colors.black45),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Acciones
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _botonGradiente(
                            'Cancelar', () => Navigator.pop(context),
                            pequeno: true),
                        const SizedBox(width: 10),
                        _botonGradiente('Guardar', () async {
                          final nombre = nombreCtrl.text.trim();
                          final cantidad =
                              int.tryParse(cantidadCtrl.text.trim());
                          final precio =
                              double.tryParse(precioCtrl.text.trim()) ??
                                  precioCtrl.text.trim();

                          if (nombre.isEmpty || cantidad == null) {
                            _mostrarFlush('Revisa nombre y cantidad',
                                Icons.error, Colors.red);
                            return;
                          }

                          final confirmar = await _mostrarConfirmacionBonita(
                            titulo: 'Guardar cambios',
                            mensaje: '¿Deseas actualizar este producto?',
                            icono: Icons.edit,
                            colores: null,
                            textoAceptar: 'Guardar',
                            textoCancelar: 'Volver',
                          );
                          if (!confirmar) return;

                          final ok = await _actualizarProductoPorId(
                            id: producto['id'],
                            nombre: nombre,
                            cantidad: cantidad,
                            precio: precio,
                            imagenFile: imagenFile,
                          );

                          if (ok) {
                            setState(() {
                              producto['nombre'] = nombre;
                              producto['cantidad'] = cantidad;
                              producto['precio'] = precio;
                            });
                            if (context.mounted) Navigator.pop(context);
                            _mostrarFlush('Producto actualizado',
                                Icons.check_circle, Colors.green);
                          } else {
                            _mostrarFlush('No se pudo actualizar',
                                Icons.error_outline, Colors.red);
                          }
                        }, pequeno: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
        debugPrint(productos.toString());
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
        debugPrint(
            encargados.toString()); // Imprime en consola la variable encargados
      }
    } catch (e) {
      debugPrint('Error al obtener encargados: $e');
    }
  }

  void _actualizarBusqueda(String query) {
    setState(() {
      productosFiltrados = productos
          .where((p) => p['nombre'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  // ===================== UI Helpers (estética igual a Inventario) =====================
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        style: GoogleFonts.poppins(),
        onChanged: _actualizarBusqueda,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'Buscar productos...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: gradientColors.first),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: gradientColors.first, width: 1.5),
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchController.clear();
                    _actualizarBusqueda('');
                  },
                  icon: const Icon(Icons.close, color: Colors.grey),
                )
              : null,
        ),
      ),
    );
  }

  Widget _botonGradiente(String texto, VoidCallback onPressed,
      {IconData? icon, bool pequeno = false, List<Color>? colores}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: pequeno
            ? const EdgeInsets.symmetric(vertical: 8, horizontal: 16)
            : const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colores ?? gradientColors),
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
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
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
          _botonGradiente("Cancelar", () => Navigator.pop(context),
              pequeno: true),
          _botonGradiente("Aceptar", () async {
            final cantidad = int.tryParse(controller.text);
            if (cantidad != null) {
              final confirmado =
                  await _mostrarConfirmacion("¿Deseas actualizar el stock?");
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
              _mostrarFlush(
                  "Stock actualizado", Icons.check_circle, Colors.green);
            }
          }),
        ],
      ),
    );
  }

  // Confirmación visual mejorada con icono y gradiente personalizados
  Future<bool> _mostrarConfirmacionBonita({
    required String titulo,
    required String mensaje,
    IconData icono = Icons.help_outline,
    List<Color>? colores,
    String textoAceptar = 'Sí',
    String textoCancelar = 'No',
  }) async {
    final grad = colores ?? gradientColors;
    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: grad),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8)
                      ],
                    ),
                    child: Icon(icono, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    titulo,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _botonGradiente(
                          textoCancelar, () => Navigator.pop(context, false),
                          pequeno: true,
                          colores: [
                            Colors.grey.shade400,
                            Colors.grey.shade600
                          ]),
                      _botonGradiente(
                          textoAceptar, () => Navigator.pop(context, true),
                          pequeno: true, colores: grad),
                    ],
                  )
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<bool> _mostrarConfirmacion(String mensaje) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirmar"),
            content: Text(mensaje),
            actions: [
              _botonGradiente("No", () => Navigator.pop(context, false),
                  pequeno: true),
              _botonGradiente("Sí", () => Navigator.pop(context, true),
                  pequeno: true),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/Logo.png', width: 200, height: 100),
                const SizedBox(height: 20),
                _botonGradiente(
                    "Llegó Pedido", () => _mostrarInputLlegoPedido(producto),
                    icon: Icons.inventory_2),
                _botonGradiente("Asignar Productos", () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('Asignar Productos'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField(
                              decoration: const InputDecoration(
                                  labelText: 'Selecciona un encargado'),
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
                              decoration: const InputDecoration(
                                  labelText: 'Cantidad a asignar'),
                              onChanged: (value) => cantidadAsignar = value,
                            ),
                          ],
                        ),
                        actions: [
                          _botonGradiente(
                              "Cancelar", () => Navigator.pop(context),
                              pequeno: true),
                          _botonGradiente("Asignar", () async {
                            final cantidad = int.tryParse(cantidadAsignar);
                            if (encargadoSeleccionado != null &&
                                cantidad != null) {
                              final confirmado = await _mostrarConfirmacion(
                                  "¿Deseas asignar este producto?");
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
                                Uri.parse(
                                    '${dotenv.env['API_EMPRESA']}api/v1/asignado'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'iduser': encargadoSeleccionado['id'],
                                  'idproduc': producto['id'],
                                  'cantidad': cantidad,
                                }),
                              );

                              // Actualiza la cantidad en producto (PUT bajo ID enviando todos los campos)
                              final nuevaCantidad =
                                  (producto['cantidad'] ?? 0) - cantidad;
                              await _actualizarProductoPorId(
                                id: producto['id'],
                                nombre: producto['nombre'],
                                cantidad: nuevaCantidad,
                                precio: producto['precio'],
                              );

                              setState(() {
                                producto['cantidad'] = nuevaCantidad;
                              });

                              Navigator.pop(context); // cerrar modal asignar
                              Navigator.pop(context); // cerrar modal producto

                              _mostrarFlush("Producto asignado correctamente",
                                  Icons.assignment_turned_in, Colors.blue);
                            }
                          }),
                        ],
                      );
                    },
                  );
                }, icon: Icons.assignment_ind),
                // Botones de editar/eliminar removidos: ahora se edita con el ícono de lápiz en la tarjeta
                // y se elimina deslizando la tarjeta hacia la izquierda (Dismissible).
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
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final maxHeight = size.height * 0.7;
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Image.asset('assets/images/Logo.png',
                      height: 90, fit: BoxFit.contain),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: historial.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text('Sin movimientos aún'),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: historial.reversed.map((mov) {
                            return ListTile(
                              leading: Icon(
                                mov['tipo'] == 'Pedido'
                                    ? Icons.add
                                    : Icons.assignment_ind,
                                color: mov['tipo'] == 'Pedido'
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                              title: Text(
                                "${mov['tipo']} de ${mov['cantidad']} unidades",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                "${mov['producto']} - ${mov['fecha'].toString().split('.')[0]}",
                                style:
                                    GoogleFonts.poppins(color: Colors.black54),
                              ),
                              trailing: mov['asignadoA'] != null
                                  ? Text(mov['asignadoA'])
                                  : null,
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: _botonGradiente(
                    'Exportar Historial',
                    () async {
                      await _exportarHistorialExcel();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: Icons.file_download,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarExportarInventarioDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Image.asset('assets/images/Logo.png',
                      height: 90, fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                _botonGradiente(
                  'Descargar Inventario General',
                  () async {
                    await _exportarExcel();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: Icons.file_download,
                ),
              ],
            ),
          ),
        );
      },
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
            onPressed: _mostrarExportarInventarioDialog,
            child: const Icon(Icons.file_download),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: SizedBox(
          height: 70,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              if (index == 0) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminView()),
                  (route) => false,
                );
              } else if (index == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MiPerfilAdmin()),
                );
              }
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home), label: "Principal"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: "Mi Perfil"),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Barra superior con degradado (consistente con Inventario)
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Encabezado: Logo, título, búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/Logo.png',
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inventario General',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: gradientColors.first,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSearchBar(),
              ],
            ),
          ),
          // Grid de productos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: productosFiltrados.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      itemCount: productosFiltrados.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, index) {
                        final producto = productosFiltrados[index];
                        final imagenNombre = (producto['imagen'] ?? '')
                            .toString()
                            .split('/')
                            .last;
                        final imagenUrl =
                            "${dotenv.env['API_GATEWAY']}imagenes/$imagenNombre";
                        final cantidad = producto['cantidad'] ?? 0;
                        final precio = producto['precio'] ?? '0';

                        return Dismissible(
                          key: Key(
                              'prod-${producto['id']?.toString() ?? 'idx-$index'}'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            final confirmado = await _mostrarConfirmacionBonita(
                              titulo: 'Eliminar producto',
                              mensaje:
                                  '¿Eliminar "${producto['nombre']}"? Esta acción no se puede deshacer.',
                              icono: Icons.delete_forever,
                              colores: [Colors.redAccent, Colors.red],
                              textoAceptar: 'Eliminar',
                              textoCancelar: 'Cancelar',
                            );
                            if (!confirmado) return false;
                            final ok = await _eliminarProductoPorId(
                                id: producto['id']);
                            if (ok) {
                              setState(() {
                                productos.removeWhere(
                                    (p) => p['id'] == producto['id']);
                                productosFiltrados.removeWhere(
                                    (p) => p['id'] == producto['id']);
                              });
                              _mostrarFlush('Producto eliminado',
                                  Icons.delete_forever, Colors.red);
                              return true;
                            } else {
                              _mostrarFlush('No se pudo eliminar',
                                  Icons.error_outline, Colors.red);
                              return false;
                            }
                          },
                          background: Container(),
                          secondaryBackground: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white, size: 28),
                          ),
                          child: _ProductTileAdmin(
                            nombre: (producto['nombre'] ?? '').toString(),
                            imagenUrl: imagenUrl,
                            cantidad: cantidad is num
                                ? cantidad.toInt()
                                : int.tryParse('$cantidad') ?? 0,
                            precioTexto: '$precio',
                            gradientColors: gradientColors,
                            onTap: () => _abrirDialogoProducto(producto),
                            onEdit: () => _mostrarEditarProducto(producto),
                            lowStock: (cantidad is num
                                    ? cantidad.toInt()
                                    : int.tryParse('$cantidad') ?? 0) <
                                10,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Tile con estética de Inventario (sin favoritos) =====================
class _ProductTileAdmin extends StatefulWidget {
  final String nombre;
  final String imagenUrl;
  final int cantidad;
  final String precioTexto;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final bool lowStock;

  const _ProductTileAdmin({
    Key? key,
    required this.nombre,
    required this.imagenUrl,
    required this.cantidad,
    required this.precioTexto,
    required this.gradientColors,
    required this.onTap,
    required this.onEdit,
    required this.lowStock,
  }) : super(key: key);

  @override
  State<_ProductTileAdmin> createState() => _ProductTileAdminState();
}

class _ProductTileAdminState extends State<_ProductTileAdmin> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(2, 4),
              )
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: widget.lowStock
                  ? Border.all(color: Colors.red, width: 2)
                  : null,
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              widget.imagenUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 64, color: Colors.grey),
                                );
                              },
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 60,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withOpacity(0.0),
                                        Colors.black.withOpacity(0.25),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            widget.nombre,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: widget.gradientColors.first,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: widget.gradientColors),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${widget.cantidad} unidades',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.attach_money,
                                    color: Colors.purple, size: 18),
                                Text(
                                  widget.precioTexto,
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onEdit,
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.edit, size: 16, color: Colors.purple),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
