import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_beauty/src/views/options_view.dart';
import 'package:app_beauty/src/views/mi_perfil_view.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:another_flushbar/flushbar.dart';

class VentasView extends StatefulWidget {
  const VentasView({super.key});

  @override
  State<VentasView> createState() => _VentasViewState();
}

class _VentasViewState extends State<VentasView> {
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  bool _loading = true;
  String? _error;
  final List<Map<String, dynamic>> _carrito = [];
  final Map<int, String> _productoNombres = {};
  final Map<int, double> _productoPreciosUnitarios =
      {}; // Almacenar precios unitarios
  // Historial de ventas
  final List<dynamic> _historial = [];
  bool _loadingHistorial = false;

  // Pago - múltiples métodos
  final Map<String, double> _metodosPago = {
    'Efectivo': 0.0,
    'Tarjeta': 0.0,
    'Transferencia': 0.0,
  };
  final Map<String, TextEditingController> _montosControllers = {
    'Efectivo': TextEditingController(),
    'Tarjeta': TextEditingController(),
    'Transferencia': TextEditingController(),
  };
  final TextEditingController _last4Ctrl = TextEditingController();
  final TextEditingController _last4TransferenciaCtrl = TextEditingController();
  final TextEditingController _descuentoCtrl = TextEditingController();
  final TextEditingController _descripcionDescuentoCtrl =
      TextEditingController();

  // Tracking de artículos especiales
  final Set<int> _articulosRegalo = {}; // Índices de items marcados como regalo
  final Set<int> _articulosPractica = {}; // Índices de items para práctica
  final Map<int, String> _descripcionesRegalo = {}; // Descripciones de regalos
  final Map<int, String> _descripcionesPractica =
      {}; // Descripciones de prácticas

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _last4Ctrl.dispose();
    _last4TransferenciaCtrl.dispose();
    _descuentoCtrl.dispose();
    _descripcionDescuentoCtrl.dispose();
    for (var ctrl in _montosControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  double get _total {
    double sum = 0.0;
    for (int i = 0; i < _carrito.length; i++) {
      // Si el artículo es regalo o práctica, no suma al total
      if (_articulosRegalo.contains(i) || _articulosPractica.contains(i)) {
        continue;
      }
      final v = _carrito[i]['total'];
      sum += (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);
    }
    return sum;
  }

  double get _totalConDescuento {
    final descuento = double.tryParse(_descuentoCtrl.text.trim()) ?? 0.0;
    return _round2((_total - descuento).clamp(0.0, double.infinity));
  }

  double _round2(double v) => double.parse(v.toStringAsFixed(2));
  String _asMoneyStr(num v) => v.toDouble().toStringAsFixed(2);
  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  // Agrupar productos del carrito por paquete_id
  List<List<Map<String, dynamic>>> _agruparCarritoPorPaquete() {
    Map<String?, List<Map<String, dynamic>>> grupos = {};

    for (int i = 0; i < _carrito.length; i++) {
      final item = _carrito[i];
      final paqueteId = item['paquete_id'] as String?;

      if (!grupos.containsKey(paqueteId)) {
        grupos[paqueteId] = [];
      }
      grupos[paqueteId]!.add({...item, '_index': i});
    }

    return grupos.values.toList();
  }

  Future<void> _fetchProductos() async {
    try {
      final uri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/producto');
      final res = await http.get(uri);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        _productoNombres.clear();
        _productoPreciosUnitarios.clear();
        if (data is List) {
          for (final el in data) {
            if (el is Map<String, dynamic>) {
              final id = _asInt(el['id']);
              final nombre = (el['nombre'] ?? '').toString();
              if (id != null && nombre.isNotEmpty) {
                _productoNombres[id] = nombre;
                // Guardar precio unitario
                final precioUnitario = el['precioUnitario'];
                if (precioUnitario != null) {
                  _productoPreciosUnitarios[id] = precioUnitario is num
                      ? precioUnitario.toDouble()
                      : double.tryParse(precioUnitario.toString()) ?? 0.0;
                }
              }
            }
          }
        }
      } else {
        // No bloquear por error de productos; solo registrar
      }
    } catch (_) {
      // Ignorar: si falla, se mostrará el fallback con ID
    }
  }

  Future<void> _finalizarVenta() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No hay productos para vender',
                style: GoogleFonts.poppins())),
      );
      return;
    }

    // Calcular total de métodos de pago
    double totalPagos = 0.0;
    final metodosPagoActivos = <Map<String, dynamic>>[];

    for (var metodo in _metodosPago.keys) {
      final monto =
          double.tryParse(_montosControllers[metodo]!.text.trim()) ?? 0.0;
      if (monto > 0) {
        totalPagos += monto;
        final pagoData = {
          'metodo': metodo.toLowerCase(),
          'monto': _round2(monto),
        };

        if (metodo == 'Tarjeta' && _last4Ctrl.text.trim().length == 4) {
          pagoData['ultimos4'] = _last4Ctrl.text.trim();
        }

        if (metodo == 'Transferencia' &&
            _last4TransferenciaCtrl.text.trim().length == 4) {
          pagoData['ultimos4'] = _last4TransferenciaCtrl.text.trim();
        }

        metodosPagoActivos.add(pagoData);
      }
    }

    // Validar que el total de pagos coincida con el total de la venta
    // Si el total es 0 (todos los artículos son regalo/práctica), no se requieren métodos de pago
    if (_totalConDescuento > 0.01) {
      if ((totalPagos - _totalConDescuento).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade400,
            content: Text(
                'El total de pagos (\$${totalPagos.toStringAsFixed(2)}) no coincide con el total de la venta (\$${_totalConDescuento.toStringAsFixed(2)})',
                style: GoogleFonts.poppins()),
          ),
        );
        return;
      }

      if (metodosPagoActivos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Debes ingresar al menos un método de pago',
                  style: GoogleFonts.poppins())),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final int? userId =
          token != null ? _asInt(JwtDecoder.decode(token)['id']) : null;

      // Armar productos con nombre, cantidad y precio unitario
      final productos = [];
      for (int i = 0; i < _carrito.length; i++) {
        final it = _carrito[i];
        final idProd =
            _asInt(it['id_producto'] ?? it['idproduc'] ?? it['producto_id']);
        final nombre = idProd != null
            ? (_productoNombres[idProd] ?? 'Producto $idProd')
            : 'Producto';
        final cantidad = (it['cantidad'] is num)
            ? (it['cantidad'] as num).toInt()
            : int.tryParse('${it['cantidad']}') ?? 0;
        final total = (it['total'] is num)
            ? (it['total'] as num).toDouble()
            : double.tryParse('${it['total']}') ?? 0.0;

        // Si es regalo o práctica, el precio es 0
        final esRegalo = _articulosRegalo.contains(i);
        final esPractica = _articulosPractica.contains(i);
        final precio = (esRegalo || esPractica)
            ? 0.0
            : (cantidad > 0 ? total / cantidad : 0.0);

        final productoData = {
          if (idProd != null) 'id_producto': idProd,
          'nombre': nombre,
          'cantidad': cantidad,
          'precio': _asMoneyStr(_round2(precio)),
        };

        // Agregar indicadores especiales
        if (esRegalo) {
          productoData['es_regalo'] = true;
          final desc = _descripcionesRegalo[i];
          if (desc != null && desc.isNotEmpty) {
            productoData['descripcion_regalo'] = desc;
          }
        }
        if (esPractica) {
          productoData['es_practica'] = true;
          final desc = _descripcionesPractica[i];
          if (desc != null && desc.isNotEmpty) {
            productoData['descripcion_practica'] = desc;
          }
        }

        productos.add(productoData);
      }

      // Agregar métodos de pago al array de productos (según el formato del backend)
      for (var metodo in _metodosPago.keys) {
        final monto =
            double.tryParse(_montosControllers[metodo]!.text.trim()) ?? 0.0;
        if (monto > 0) {
          final pagoData = {
            'monto': _asMoneyStr(_round2(monto)),
            'metodo': metodo.toLowerCase(),
          };

          if (metodo == 'Tarjeta' && _last4Ctrl.text.trim().length == 4) {
            pagoData['ultimos4'] = _last4Ctrl.text.trim();
          }

          if (metodo == 'Transferencia' &&
              _last4TransferenciaCtrl.text.trim().length == 4) {
            pagoData['ultimos4'] = _last4TransferenciaCtrl.text.trim();
          }

          productos.add(pagoData);
        }
      }

      final descuento = double.tryParse(_descuentoCtrl.text.trim()) ?? 0.0;
      final descripcionDescuento = _descripcionDescuentoCtrl.text.trim();

      // Agregar descuento al array de productos si existe
      if (descuento > 0) {
        productos.add({
          'descuento': _asMoneyStr(descuento),
          'tipo': 'descuento',
          if (descripcionDescuento.isNotEmpty)
            'descripcion': descripcionDescuento,
        });
      }

      final body = jsonEncode({
        'id_encargado': userId,
        'total_final': _asMoneyStr(_totalConDescuento),
        if (descuento > 0) 'descuento': _asMoneyStr(descuento),
        if (descuento > 0 && descripcionDescuento.isNotEmpty)
          'descripcion_descuento': descripcionDescuento,
        'productos': productos,
      });

      // Debug: Imprimir el JSON que se enviará
      debugPrint('[POST Venta] Body JSON: $body');

      // Usar directamente el endpoint que sí responde OK (API_EMPRESA)
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final baseEmpresa = (dotenv.env['API_EMPRESA'] ?? '').trim();
      final uri = Uri.parse(baseEmpresa).resolve('api/v1/venta');
      debugPrint('[POST Venta] ${uri.toString()}');
      final res = await http.post(uri, headers: headers, body: body);

      debugPrint('[POST Venta] Response status: ${res.statusCode}');
      debugPrint('[POST Venta] Response body: ${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        try {
          debugPrint('[POST Venta] OK via ${uri.toString()}');
        } catch (_) {}
        Map<String, dynamic>? respJson;
        try {
          respJson = jsonDecode(res.body);
        } catch (_) {}

        // Actualizar cantidades en la tabla asignado después de venta exitosa
        await _actualizarCantidadesAsignadas(
            userId, productos.cast<Map<String, dynamic>>());

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Ticket de Venta',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (respJson != null &&
                        (respJson['id'] != null || respJson['folio'] != null))
                      Text('Folio: ${respJson['folio'] ?? respJson['id']}',
                          style: GoogleFonts.poppins()),
                    Text('Encargado: ${userId ?? '-'}',
                        style: GoogleFonts.poppins()),
                    const SizedBox(height: 8),
                    Text('Métodos de pago:',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    // Filtrar solo los métodos de pago del array productos
                    ...productos
                        .where((item) => item['metodo'] != null)
                        .map((mp) {
                      final metodo = mp['metodo'] ?? '';
                      final montoStr = mp['monto'] ?? '0.00';
                      final monto = double.tryParse(montoStr.toString()) ?? 0.0;
                      final last4 = mp['ultimos4'] ?? '';
                      String metodoTexto;

                      if (metodo == 'tarjeta' && last4.isNotEmpty) {
                        metodoTexto = 'Tarjeta **** $last4';
                      } else if (metodo == 'transferencia' &&
                          last4.isNotEmpty) {
                        metodoTexto = 'Transferencia **** $last4';
                      } else {
                        metodoTexto =
                            '${metodo[0].toUpperCase()}${metodo.substring(1)}';
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(metodoTexto, style: GoogleFonts.poppins()),
                            Text('\$${monto.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    const Divider(),
                    Text('Productos:',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    // Filtrar solo los productos reales (que tienen 'nombre')
                    ...productos
                        .where((item) => item['nombre'] != null)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      final p = entry.value;
                      final idx = entry.key;
                      final esRegalo = _articulosRegalo.contains(idx);
                      final esPractica = _articulosPractica.contains(idx);

                      String extras = '';
                      if (esRegalo) extras += ' 🎁';
                      if (esPractica) extras += ' 📚';

                      final precioStr = p['precio']?.toString() ?? '0.00';
                      final precio = double.tryParse(precioStr) ?? 0.0;

                      String? descripcion;
                      if (esRegalo) {
                        descripcion = _descripcionesRegalo[idx];
                      } else if (esPractica) {
                        descripcion = _descripcionesPractica[idx];
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                    child: Text(
                                        '${p['nombre']} x${p['cantidad']}$extras',
                                        style: GoogleFonts.poppins())),
                                Text('\$${precio.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            if (descripcion != null && descripcion.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: Text(
                                  '↳ $descripcion',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    if (descuento > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal', style: GoogleFonts.poppins()),
                          Text('\$${_round2(_total).toStringAsFixed(2)}',
                              style: GoogleFonts.poppins()),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Descuento',
                                    style: GoogleFonts.poppins(
                                        color: Colors.green)),
                                if (_descripcionDescuentoCtrl.text
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    '(${_descripcionDescuentoCtrl.text.trim()})',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text('-\$${descuento.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    // Mostrar nota si hay artículos gratis
                    if (_articulosRegalo.isNotEmpty ||
                        _articulosPractica.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '* Artículos marcados como 🎁 Regalo o 📚 Práctica no tienen costo',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700)),
                        Text(
                            '\$${_round2(_totalConDescuento).toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cerrar', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );

        // Vaciar carrito en backend por ID de items/encargado para evitar duplicados al actualizar
        try {
          if (userId != null) {
            await _vaciarCarritoBackend(userId, token: token);
          }
        } catch (e) {
          debugPrint('No se pudo vaciar carrito backend: $e');
        }

        // Limpiar carrito local y métodos de pago después de vender
        setState(() {
          _carrito.clear();
          _loading = false;
          // Limpiar todos los campos de pago
          _last4Ctrl.clear();
          _last4TransferenciaCtrl.clear();
          _descuentoCtrl.clear();
          _descripcionDescuentoCtrl.clear();
          for (var ctrl in _montosControllers.values) {
            ctrl.clear();
          }
          // Limpiar marcadores de artículos especiales
          _articulosRegalo.clear();
          _articulosPractica.clear();
          _descripcionesRegalo.clear();
          _descripcionesPractica.clear();
        });

        _showTopBar(
            '¡Venta finalizada!', 'Se registró la venta correctamente.');
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade400,
            content: Text('Error al crear venta (${res.statusCode}).',
                style: GoogleFonts.poppins()),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: Text('Error: $e', style: GoogleFonts.poppins()),
        ),
      );
    }
  }

  void _showTopBar(String title, String message) {
    // Mensaje tipo nav bar superior (Flushbar) similar a OptionsView
    Flushbar(
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(15),
      backgroundColor: gradientStart,
      flushbarPosition: FlushbarPosition.TOP,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
      titleText: Text(title,
          style: const TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
      messageText: Text(message,
          style: const TextStyle(fontSize: 14, color: Colors.white)),
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 400),
    ).show(context);
  }

  Future<void> _mostrarDialogoDescripcion(int index, bool esRegalo) async {
    final tipo = esRegalo ? 'Regalo' : 'Práctica';
    final emoji = esRegalo ? '🎁' : '📚';
    final controller = TextEditingController(
        text: esRegalo
            ? (_descripcionesRegalo[index] ?? '')
            : (_descripcionesPractica[index] ?? ''));

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('Descripción de $tipo',
                style: GoogleFonts.poppins(fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '¿Por qué es un $tipo?',
            hintText: 'Ej: Promoción del mes, Material de curso, etc.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Cancelar - remover la marca
              setState(() {
                if (esRegalo) {
                  _articulosRegalo.remove(index);
                  _descripcionesRegalo.remove(index);
                } else {
                  _articulosPractica.remove(index);
                  _descripcionesPractica.remove(index);
                }
              });
              Navigator.pop(context);
            },
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              final descripcion = controller.text.trim();
              if (descripcion.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Por favor ingresa una descripción',
                        style: GoogleFonts.poppins()),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              setState(() {
                if (esRegalo) {
                  _descripcionesRegalo[index] = descripcion;
                } else {
                  _descripcionesPractica[index] = descripcion;
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: gradientEnd,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Guardar',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Elimina del backend los items del carrito del encargado dado.
  // Estrategia:
  // 1) GET api/v1/carrito -> localizar items del usuario y DELETE api/v1/carrito/{id}
  // 2) Si no hay IDs, intentar un DELETE masivo por encargado: api/v1/carrito/encargado/{userId}

  Future<void> _actualizarCantidadesAsignadas(
      int? userId, List<Map<String, dynamic>> productos) async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseEmpresa = (dotenv.env['API_EMPRESA'] ?? '').trim();

      // Obtener los registros de asignación del usuario actual
      final getUri =
          Uri.parse(baseEmpresa).resolve('api/v1/asignado/user/$userId');
      debugPrint(
          '[GET asignado] Obteniendo asignaciones del usuario $userId: ${getUri.toString()}');

      final getRes = await http.get(getUri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      debugPrint('[GET asignado] Status: ${getRes.statusCode}');
      debugPrint('[GET asignado] Response: ${getRes.body}');

      if (getRes.statusCode >= 200 && getRes.statusCode < 300) {
        final asignaciones = jsonDecode(getRes.body) as List;
        debugPrint(
            '[GET asignado] Total asignaciones del usuario: ${asignaciones.length}');

        // Filtrar productos reales (que tienen id_producto)
        for (var prod in productos) {
          final idProducto = _asInt(prod['id_producto']);
          if (idProducto == null) continue;

          final cantidadVendida = prod['cantidad'] is num
              ? (prod['cantidad'] as num).toInt()
              : int.tryParse('${prod['cantidad']}') ?? 0;

          if (cantidadVendida <= 0) continue;

          debugPrint(
              '[Procesando] Producto ID: $idProducto, Cantidad vendida: $cantidadVendida');

          // Buscar la asignación de este producto para este usuario
          final asignacion = asignaciones.firstWhere(
            (a) {
              final aUserId = _asInt(a['iduser']);
              final aProdId = _asInt(a['idproduc']);
              debugPrint(
                  '[Comparando] Asignación - userId: $aUserId (busco: $userId), productoId: $aProdId (busco: $idProducto)');
              return aUserId == userId && aProdId == idProducto;
            },
            orElse: () => null,
          );

          if (asignacion != null) {
            final asignacionId = _asInt(asignacion['id']);
            final cantidadActual = asignacion['cantidad'] is num
                ? (asignacion['cantidad'] as num).toInt()
                : int.tryParse('${asignacion['cantidad']}') ?? 0;

            // Calcular nueva cantidad
            final nuevaCantidad = (cantidadActual - cantidadVendida)
                .clamp(0, double.infinity)
                .toInt();

            debugPrint(
                '[Calculando] Producto $idProducto: cantidad actual=$cantidadActual, vendida=$cantidadVendida, nueva=$nuevaCantidad');

            // Actualizar con PUT
            if (asignacionId != null) {
              final putUri = Uri.parse(baseEmpresa)
                  .resolve('api/v1/asignado/$asignacionId');
              final putBody = jsonEncode({
                'iduser': userId,
                'idproduc': idProducto,
                'cantidad': nuevaCantidad,
              });

              debugPrint('[PUT asignado/$asignacionId] Body: $putBody');

              final putRes = await http.put(
                putUri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  if (token != null) 'Authorization': 'Bearer $token',
                },
                body: putBody,
              );

              debugPrint(
                  '[PUT asignado/$asignacionId] Status: ${putRes.statusCode} - Nueva cantidad: $nuevaCantidad');
              debugPrint(
                  '[PUT asignado/$asignacionId] Response: ${putRes.body}');

              if (putRes.statusCode >= 200 && putRes.statusCode < 300) {
                debugPrint(
                    '✅ Actualizado producto $idProducto: $cantidadActual -> $nuevaCantidad');
              } else {
                debugPrint(
                    '⚠️ Error al actualizar producto $idProducto: ${putRes.body}');
              }
            }
          } else {
            debugPrint(
                '⚠️ No se encontró asignación para producto $idProducto del usuario $userId');
          }
        }
      }
    } catch (e) {
      debugPrint('Error al actualizar cantidades asignadas: $e');
    }
  }

  Future<void> _vaciarCarritoBackend(int userId, {String? token}) async {
    final base = (dotenv.env['API_EMPRESA'] ?? '').trim();
    final headers = {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    // 1) Obtener carrito e intentar borrar por ID
    try {
      final getUri = Uri.parse(base).resolve('api/v1/carrito');
      final getRes = await http.get(getUri, headers: headers);
      if (getRes.statusCode >= 200 && getRes.statusCode < 300) {
        final data = jsonDecode(getRes.body);
        final List<dynamic> items = (data is List) ? data : const [];
        final ids = <int>[];
        for (final el in items) {
          if (el is Map<String, dynamic>) {
            final encId = _asInt(el['id_encargado'] ??
                el['idEncargado'] ??
                el['id_user'] ??
                el['idusuario'] ??
                el['idUser']);
            if (encId == userId) {
              final itemId =
                  _asInt(el['id'] ?? el['id_carrito'] ?? el['carrito_id']);
              if (itemId != null) ids.add(itemId);
            }
          }
        }

        if (ids.isNotEmpty) {
          for (final id in ids) {
            try {
              final delUri = Uri.parse(base).resolve('api/v1/carrito/$id');
              final delRes = await http.delete(delUri, headers: headers);
              debugPrint('[DELETE carrito/$id] ${delRes.statusCode}');
            } catch (e) {
              debugPrint('Error al eliminar item carrito $id: $e');
            }
          }
          return; // listo
        }
      }
    } catch (e) {
      debugPrint('No se pudo consultar carrito para vaciar: $e');
    }

    // 2) Fallback: intentar borrado masivo por encargado
    try {
      final delAll =
          Uri.parse(base).resolve('api/v1/carrito/encargado/$userId');
      final res = await http.delete(delAll, headers: headers);
      debugPrint('[DELETE carrito/encargado/$userId] ${res.statusCode}');
    } catch (e) {
      debugPrint('Error en borrado masivo de carrito por encargado: $e');
    }
  }

  Future<void> _fetchHistorial() async {
    setState(() => _loadingHistorial = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final int? userId =
          token != null ? _asInt(JwtDecoder.decode(token)['id']) : null;
      if (userId == null) throw Exception('Usuario no válido');

      // Usar el endpoint de historial en API_EMPRESA
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final baseEmpresa = (dotenv.env['API_EMPRESA'] ?? '').trim();
      final uri =
          Uri.parse(baseEmpresa).resolve('api/v1/venta/encargado/$userId');
      debugPrint('[GET Historial] ${uri.toString()}');
      final res = await http.get(uri, headers: headers);
      if (!(res.statusCode >= 200 && res.statusCode < 300)) {
        throw Exception('Error ${res.statusCode}');
      }
      final data = jsonDecode(res.body);
      _historial
        ..clear()
        ..addAll(data is List ? data : []);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: Text('No se pudo cargar el historial: $e',
              style: GoogleFonts.poppins()),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingHistorial = false);
    }
  }

  Future<void> _showHistorialSheet() async {
    await _fetchHistorial();
    if (!mounted) return;

    // Calcular el total de todas las ventas
    double totalVentas = 0.0;
    for (final venta in _historial) {
      if (venta is Map<String, dynamic>) {
        final totalStr =
            (venta['total_final'] ?? venta['total'] ?? '0.00').toString();
        final total = double.tryParse(totalStr) ?? 0.0;
        totalVentas += total;
      }
    }

    // Muestra historial en un bottom sheet
    // (Diseño simple para validar la API rápidamente)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Historial de Ventas',
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Mostrar total de ventas
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            gradientStart.withOpacity(0.15),
                            gradientEnd.withOpacity(0.15)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: gradientStart.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monetization_on,
                                  color: gradientEnd, size: 24),
                              const SizedBox(width: 8),
                              Text('Total de Ventas:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  )),
                            ],
                          ),
                          Text('\$${totalVentas.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: gradientEnd,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingHistorial)
                      const Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator()))
                    else if (_historial.isEmpty)
                      Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('Sin ventas aún',
                                  style: GoogleFonts.poppins())))
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _historial.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final v = _historial[i] as Map<String, dynamic>;
                            final folio = v['id'] ?? v['folio'] ?? '-';
                            final total =
                                (v['total_final'] ?? v['total'])?.toString() ??
                                    '0.00';
                            final productos = (v['productos'] is List)
                                ? (v['productos'] as List)
                                : const [];
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 3))
                                ],
                              ),
                              child: ExpansionTile(
                                title: Text('Folio $folio',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total: \$$total',
                                        style: GoogleFonts.poppins(
                                            color: Colors.grey.shade700)),
                                    Builder(builder: (_) {
                                      // Extraer métodos de pago del array de productos
                                      final metodosPago = productos
                                          .where((item) =>
                                              item is Map &&
                                              item['metodo'] != null)
                                          .toList();

                                      if (metodosPago.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Pagos:',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600)),
                                          ...metodosPago.map((mp) {
                                            final metodo =
                                                (mp['metodo'] ?? '').toString();
                                            final monto =
                                                (mp['monto'] ?? '').toString();
                                            final last4 = (mp['ultimos4'] ?? '')
                                                .toString();

                                            final metodoTexto = metodo.isEmpty
                                                ? 'N/D'
                                                : metodo[0].toUpperCase() +
                                                    metodo.substring(1);

                                            final pagoTexto = (metodo
                                                                .toLowerCase() ==
                                                            'tarjeta' ||
                                                        metodo.toLowerCase() ==
                                                            'transferencia') &&
                                                    last4.isNotEmpty
                                                ? '$metodoTexto **** $last4: \$$monto'
                                                : '$metodoTexto: \$$monto';

                                            return Text(
                                              pagoTexto,
                                              style: GoogleFonts.poppins(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 11),
                                            );
                                          }),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                                children: [
                                  // Mostrar solo los productos reales (que tienen 'nombre')
                                  ...productos
                                      .where((p) =>
                                          p is Map && p['nombre'] != null)
                                      .map((p) {
                                    final nombre =
                                        (p['nombre'] ?? '').toString();
                                    final precio =
                                        (p['precio'] ?? '').toString();
                                    final cantidad = p['cantidad'] ?? 0;

                                    // Indicadores de regalo o práctica
                                    String extras = '';
                                    if (p['es_regalo'] == true) extras += ' 🎁';
                                    if (p['es_practica'] == true)
                                      extras += ' 📚';

                                    final descripcionRegalo =
                                        p['descripcion_regalo']?.toString();
                                    final descripcionPractica =
                                        p['descripcion_practica']?.toString();
                                    final descripcion = descripcionRegalo ??
                                        descripcionPractica;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          dense: true,
                                          title: Text('$nombre$extras',
                                              style: GoogleFonts.poppins()),
                                          trailing: Text(
                                              '${cantidad} x \$$precio',
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        if (descripcion != null &&
                                            descripcion.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 72, bottom: 8),
                                            child: Text(
                                              '↳ $descripcion',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 0, 12, 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                Colors.red.shade600,
                                          ),
                                          onPressed:
                                              _asInt(v['id'] ?? v['folio']) ==
                                                      null
                                                  ? null
                                                  : () async {
                                                      final idVenta = _asInt(
                                                          v['id'] ??
                                                              v['folio']);
                                                      if (idVenta == null)
                                                        return;
                                                      final ok =
                                                          await showDialog<
                                                                  bool>(
                                                                context:
                                                                    context,
                                                                builder: (dctx) =>
                                                                    AlertDialog(
                                                                  title: Text(
                                                                      'Eliminar venta',
                                                                      style: GoogleFonts.poppins(
                                                                          fontWeight:
                                                                              FontWeight.w700)),
                                                                  content: Text(
                                                                      '¿Seguro que deseas eliminar la venta #$idVenta? Esta acción no se puede deshacer.',
                                                                      style: GoogleFonts
                                                                          .poppins()),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () => Navigator.pop(
                                                                          dctx,
                                                                          false),
                                                                      child: Text(
                                                                          'Cancelar',
                                                                          style:
                                                                              GoogleFonts.poppins()),
                                                                    ),
                                                                    TextButton(
                                                                      onPressed: () => Navigator.pop(
                                                                          dctx,
                                                                          true),
                                                                      child: Text(
                                                                          'Eliminar',
                                                                          style:
                                                                              GoogleFonts.poppins(color: Colors.red)),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ) ??
                                                              false;
                                                      if (!ok) return;
                                                      await _eliminarVentaPorId(
                                                          idVenta,
                                                          setModalState,
                                                          ctx);
                                                    },
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          label: Text('Eliminar',
                                              style: GoogleFonts.poppins()),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            );
                          },
                        ), // cierre ListView.separated
                      ), // cierre Flexible
                  ], // cierre children de Column
                ), // cierre Column
              ), // cierre Padding
            ); // cierre SafeArea
          }, // cierre builder de StatefulBuilder
        ); // cierre StatefulBuilder
      }, // cierre builder de showModalBottomSheet
    ); // cierre showModalBottomSheet
  }

  Future<void> _exportarVentas() async {
    try {
      if (_historial.isEmpty) {
        await _fetchHistorial();
      }
      if (_historial.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('No hay ventas para exportar',
                  style: GoogleFonts.poppins())),
        );
        return;
      }

      // Crear contenido CSV
      final csvRows = <String>[];

      // Encabezados
      final headers = [
        'Folio',
        'Encargado',
        'Fecha',
        'Efectivo',
        'Tarjeta',
        'Transferencia',
        'Tarjeta Ultimos 4',
        'Transferencia Ultimos 4',
        'Total',
        'Descuento',
        'Descripcion Descuento',
        'Productos',
        'Cantidades',
        'Precios de Compra',
        'Precios de Venta',
        'Ganancia por Producto',
        'Ganancia Total',
        'Tipo (Venta/Regalo/Practica)',
        'Descripcion Regalo/Practica',
      ];
      csvRows.add(headers.join(';')); // Usar punto y coma como delimitador

      // Obtener precios de compra de productos desde el API
      final Map<int, double> preciosUnitarios = {};
      try {
        final uri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/producto');
        final res = await http.get(uri);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          if (data is List) {
            for (final el in data) {
              if (el is Map<String, dynamic>) {
                final id = _asInt(el['id']);
                final precioUnitario = el['precioUnitario'];
                if (id != null && precioUnitario != null) {
                  preciosUnitarios[id] = precioUnitario is num
                      ? precioUnitario.toDouble()
                      : double.tryParse(precioUnitario.toString()) ?? 0.0;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error al obtener precios de compra: $e');
      }

      int appended = 0;
      double totalGeneral = 0.0;
      double gananciaGeneralTotal = 0.0;

      for (final raw in _historial) {
        if (raw is! Map) continue;
        final m = raw as Map;

        final folio = (m['folio'] ?? m['id'] ?? '').toString();

        // Encargado
        final encargadoVal = m['id_encargado'] ??
            m['encargado'] ??
            m['idUser'] ??
            m['usuario'] ??
            '';
        final encargado = encargadoVal?.toString() ?? '';

        // Fecha - procesamiento mejorado
        dynamic fechaRaw = m['fecha_venta'] ??
            m['fecha'] ??
            m['created_at'] ??
            m['fecha_creacion'] ??
            m['fechaVenta'] ??
            m['createdAt'] ??
            '';
        String fecha = '-';

        if (fechaRaw != null && fechaRaw != '') {
          if (fechaRaw is DateTime) {
            fecha = fechaRaw.toIso8601String().substring(0, 10); // YYYY-MM-DD
          } else {
            final fechaStr = fechaRaw.toString();
            // Intentar parsear diferentes formatos de fecha
            try {
              final dt = DateTime.parse(fechaStr);
              fecha = dt.toIso8601String().substring(0, 10); // YYYY-MM-DD
            } catch (_) {
              // Si falla el parseo, usar el string tal cual
              fecha =
                  fechaStr.length > 10 ? fechaStr.substring(0, 10) : fechaStr;
            }
          }
        }

        final total = (m['total_final'] ?? m['total'] ?? '0.00').toString();
        final totalNum = double.tryParse(total) ?? 0.0;
        totalGeneral += totalNum;

        // Descuento - manejar diferentes tipos de datos
        dynamic descuentoRaw = m['descuento'];
        String descuento = '0.00';
        String descripcionDescuento = '';
        if (descuentoRaw != null) {
          if (descuentoRaw is num) {
            descuento = descuentoRaw.toStringAsFixed(2);
          } else if (descuentoRaw is String && descuentoRaw.isNotEmpty) {
            final parsedDescuento = double.tryParse(descuentoRaw);
            descuento = parsedDescuento != null
                ? parsedDescuento.toStringAsFixed(2)
                : '0.00';
          }
        }

        // Obtener descripción del descuento
        descripcionDescuento = (m['descripcion_descuento'] ?? '').toString();

        // Productos - Ahora incluyen métodos de pago en el mismo array
        dynamic rawProds = m['productos'];
        List productosRaw;
        if (rawProds is List) {
          productosRaw = rawProds;
        } else if (rawProds is String) {
          try {
            final decoded = jsonDecode(rawProds);
            productosRaw = (decoded is List) ? decoded : [];
          } catch (_) {
            productosRaw = [];
          }
        } else {
          productosRaw = [];
        }

        // Separar productos de métodos de pago
        final nombresProductos = <String>[];
        final cantidades = <String>[];
        final precios = <String>[];
        final preciosUnitariosStr = <String>[];
        final gananciasStr = <String>[];
        final tipos = <String>[]; // Nuevo: tipo de transacción
        final descripciones =
            <String>[]; // Nuevo: descripciones de regalo/práctica

        double gananciaVenta = 0.0;

        // Separar métodos de pago por tipo
        String efectivo = '-';
        String tarjeta = '-';
        String tarjetaLast4 = '-';
        String transferencia = '-';
        String transferenciaLast4 = '-';

        for (var item in productosRaw) {
          if (item is Map) {
            // Si tiene 'nombre', es un producto
            if (item['nombre'] != null) {
              nombresProductos.add((item['nombre'] ?? 'Producto').toString());
              final cantidadItem =
                  int.tryParse((item['cantidad'] ?? '0').toString()) ?? 0;
              cantidades.add(cantidadItem.toString());
              final precioVenta =
                  double.tryParse((item['precio'] ?? '0.00').toString()) ?? 0.0;
              precios.add(precioVenta.toStringAsFixed(2));

              // Obtener ID del producto para buscar precio unitario
              final idProducto = _asInt(item['id_producto'] ??
                  item['idproduc'] ??
                  item['producto_id']);
              final precioUnitario = (idProducto != null &&
                      preciosUnitarios.containsKey(idProducto))
                  ? preciosUnitarios[idProducto]!
                  : 0.0;
              preciosUnitariosStr.add(precioUnitario.toStringAsFixed(2));

              // Calcular ganancia por producto (precio venta - precio unitario) * cantidad
              final gananciaPorProducto =
                  (precioVenta - precioUnitario) * cantidadItem;
              gananciasStr.add(gananciaPorProducto.toStringAsFixed(2));

              // Determinar el tipo: Regalo, Práctica o Venta
              String tipo = 'Venta';
              String descripcion = '-';

              if (item['es_regalo'] == true) {
                tipo = 'Regalo';
                descripcion = item['descripcion_regalo']?.toString() ?? '-';
                // Los regalos no generan ganancia
              } else if (item['es_practica'] == true) {
                tipo = 'Practica';
                descripcion = item['descripcion_practica']?.toString() ?? '-';
                // Las prácticas no generan ganancia
              } else {
                // Solo sumar ganancia si es venta real
                gananciaVenta += gananciaPorProducto;
              }
              tipos.add(tipo);
              descripciones.add(descripcion);
            }
            // Si tiene 'tipo' == 'descuento', extraer el descuento
            else if (item['tipo'] == 'descuento' && item['descuento'] != null) {
              final descuentoItem = item['descuento'].toString();
              final parsedDesc = double.tryParse(descuentoItem);
              if (parsedDesc != null && parsedDesc > 0) {
                descuento = parsedDesc.toStringAsFixed(2);
              }
              // Extraer descripción del descuento si existe
              if (item['descripcion'] != null) {
                descripcionDescuento = item['descripcion'].toString();
              }
            }
            // Si tiene 'metodo', es un método de pago
            else if (item['metodo'] != null) {
              final metodo = (item['metodo'] ?? '').toString().toLowerCase();
              final monto = (item['monto'] ?? '0.00').toString();
              final last4 = (item['ultimos4'] ?? '').toString();

              if (metodo == 'efectivo') {
                efectivo = monto;
              } else if (metodo == 'tarjeta') {
                tarjeta = monto;
                if (last4.isNotEmpty) {
                  tarjetaLast4 = '****$last4';
                }
              } else if (metodo == 'transferencia') {
                transferencia = monto;
                if (last4.isNotEmpty) {
                  transferenciaLast4 = '****$last4';
                }
              }
            }
          }
        }

        final productosStr =
            nombresProductos.join(' | '); // Usar | en lugar de ;
        final cantidadesStr = cantidades.join(' | ');
        final preciosStr = precios.join(' | ');
        final preciosUnitariosStrJoined = preciosUnitariosStr.join(' | ');
        final gananciasStrJoined = gananciasStr.join(' | ');
        final tiposStr = tipos.join(' | '); // Nuevo: tipos separados por |
        final descripcionesStr =
            descripciones.join(' | '); // Nuevo: descripciones separadas por |

        // Sumar ganancia de esta venta al total general
        gananciaGeneralTotal += gananciaVenta;

        // Agregar fila al CSV con columnas separadas por método de pago
        // Orden: Folio, Encargado, Fecha, Efectivo, Tarjeta, Transferencia,
        //        Tarjeta Ultimos 4, Transferencia Ultimos 4, Total, Descuento, Descripcion Descuento,
        //        Productos, Cantidades, Precios de Compra, Precios de Venta, Ganancia por Producto, Ganancia Total, Tipo, Descripcion Regalo/Practica
        final row = [
          folio,
          encargado,
          fecha,
          efectivo,
          tarjeta,
          transferencia,
          tarjetaLast4,
          transferenciaLast4,
          total,
          descuento,
          descripcionDescuento.isEmpty ? '-' : descripcionDescuento,
          productosStr.isEmpty ? 'Sin productos' : productosStr,
          cantidadesStr.isEmpty ? '-' : cantidadesStr,
          preciosUnitariosStrJoined.isEmpty ? '-' : preciosUnitariosStrJoined,
          preciosStr.isEmpty ? '-' : preciosStr,
          gananciasStrJoined.isEmpty ? '-' : gananciasStrJoined,
          gananciaVenta.toStringAsFixed(2),
          tiposStr.isEmpty ? '-' : tiposStr, // Nueva columna
          descripcionesStr.isEmpty
              ? '-'
              : descripcionesStr, // Nueva columna de descripciones
        ];
        csvRows.add(row.join(';')); // Usar punto y coma como delimitador
        appended++;
      }

      // Agregar fila de totales al final
      if (appended > 0) {
        csvRows.add(''); // Línea en blanco para separar
        final rowTotales = [
          'TOTAL GENERAL',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '\$${totalGeneral.toStringAsFixed(2)}',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '\$${gananciaGeneralTotal.toStringAsFixed(2)}', // Ganancia total
          '',
        ];
        csvRows.add(rowTotales.join(';'));
      }

      // Agregar BOM UTF-8 para compatibilidad con Excel
      final csvContent = csvRows.join('\r\n'); // Usar CRLF para Windows
      final bomUtf8 = [0xEF, 0xBB, 0xBF]; // BOM para UTF-8
      final contentBytes = utf8.encode(csvContent);
      final bytes = Uint8List.fromList([...bomUtf8, ...contentBytes]);

      final fileName =
          'ventas_${DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19)}.csv';

      // Compartir/Guardar el archivo
      await _shareFile(bytes, fileName);

      if (!mounted) return;
      _showTopBar(
          'CSV exportado',
          appended > 0
              ? 'Se preparó $fileName con $appended ventas.'
              : 'Se preparó $fileName (sin filas)');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: Text('Error al exportar: $e', style: GoogleFonts.poppins()),
        ),
      );
    }
  }

  // Método para escapar valores CSV
  String _escapeCsv(String value) {
    // Solo envolver en comillas si contiene caracteres especiales
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r') ||
        value.startsWith(' ') ||
        value.endsWith(' ')) {
      // Escapar comillas duplicándolas
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  Future<void> _shareFile(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      // En web, descargar el archivo
      final mimeType =
          fileName.endsWith('.csv') ? 'text/csv' : 'application/octet-stream';
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    final f = io.File(path);
    await f.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(path)], text: 'Reporte de ventas');
  }

  Future<void> _shareExcel(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      // En web, compartir archivos binarios no está soportado ampliamente; fallback a descarga
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    final f = io.File(path);
    await f.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(path)], text: 'Ventas exportadas');
  }

  Future<void> _eliminarVentaPorId(int idVenta,
      [StateSetter? setModalState, BuildContext? modalContext]) async {
    try {
      // Mostrar loading en el modal si está disponible
      if (setModalState != null) {
        setModalState(() {
          _loadingHistorial = true;
        });
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final baseEmpresa = (dotenv.env['API_EMPRESA'] ?? '').trim();
      final uri = Uri.parse(baseEmpresa).resolve('api/v1/venta/$idVenta');
      debugPrint('[DELETE Venta] ${uri.toString()}');
      final res = await http.delete(uri, headers: headers);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (!mounted) return;

        // Mostrar confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Venta #$idVenta eliminada',
                  style: GoogleFonts.poppins())),
        );

        // Cerrar el modal actual
        if (modalContext != null && Navigator.canPop(modalContext)) {
          Navigator.pop(modalContext);
        }

        // Esperar un momento para que se cierre el modal
        await Future.delayed(const Duration(milliseconds: 300));

        // Reabrir el modal con datos actualizados
        if (mounted) {
          await _showHistorialSheet();
        }
      } else {
        throw Exception('Estado ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;

      // Resetear loading
      if (setModalState != null) {
        setModalState(() {
          _loadingHistorial = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: Text('No se pudo eliminar la venta: $e',
              style: GoogleFonts.poppins()),
        ),
      );
    }
  }

  Future<void> _fetchCarritoOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final int? userId =
        token != null ? _asInt(JwtDecoder.decode(token)['id']) : null;
    final uri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/carrito');
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      _carrito.clear();
      if (data is List) {
        for (final el in data) {
          if (el is Map<String, dynamic>) {
            if (userId == null) {
              _carrito.add(el);
              continue;
            }
            final encId = _asInt(el['id_encargado'] ??
                el['idEncargado'] ??
                el['id_user'] ??
                el['idusuario'] ??
                el['idUser']);
            if (encId != null && encId == userId) {
              _carrito.add(el);
            }
          }
        }
      }
    } else {
      throw Exception('Error ${res.statusCode} al obtener carrito');
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([
        _fetchProductos(),
        _fetchCarritoOnly(),
      ]);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior con gradiente
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradientStart, gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Image.asset('assets/images/Logo.png',
                      height: 80, fit: BoxFit.contain),
                  const SizedBox(height: 6),
                  Text(
                    'Ventas',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Acciones
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showHistorialSheet,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text('Historial',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportarVentas,
                      icon: const Icon(Icons.description_outlined),
                      label: Text('Reporte de ventas',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            // Lista de items
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(_error!, style: GoogleFonts.poppins()))
                        : _carrito.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.receipt_long,
                                        size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text('Aún no hay productos en la venta',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade600,
                                        )),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _carrito.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final it = _carrito[index];
                                  final idProd = it['id_producto'] ??
                                      it['idproduc'] ??
                                      it['producto_id'] ??
                                      '-';
                                  final idProdInt = _asInt(idProd);
                                  final nombreProd = idProdInt != null
                                      ? (_productoNombres[idProdInt] ??
                                          'Producto $idProd')
                                      : 'Producto $idProd';
                                  final cantidad = (it['cantidad'] is num)
                                      ? (it['cantidad'] as num).toInt()
                                      : int.tryParse('${it['cantidad']}') ?? 0;
                                  final total = (it['total'] is num)
                                      ? (it['total'] as num).toDouble()
                                      : double.tryParse('${it['total']}') ??
                                          0.0;
                                  final precioU =
                                      cantidad > 0 ? total / cantidad : 0.0;
                                  final esRegalo =
                                      _articulosRegalo.contains(index);
                                  final esPractica =
                                      _articulosPractica.contains(index);

                                  // Si es regalo o práctica, mostrar precio $0
                                  final precioMostrar =
                                      (esRegalo || esPractica) ? 0.0 : precioU;
                                  final totalMostrar =
                                      (esRegalo || esPractica) ? 0.0 : total;

                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: LinearGradient(
                                        colors: [
                                          gradientStart.withOpacity(0.12),
                                          gradientEnd.withOpacity(0.12)
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  nombreProd,
                                                  style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ),
                                              if (esRegalo)
                                                const Padding(
                                                  padding:
                                                      EdgeInsets.only(left: 4),
                                                  child: Text('🎁',
                                                      style: TextStyle(
                                                          fontSize: 16)),
                                                ),
                                              if (esPractica)
                                                const Padding(
                                                  padding:
                                                      EdgeInsets.only(left: 4),
                                                  child: Text('📚',
                                                      style: TextStyle(
                                                          fontSize: 16)),
                                                ),
                                            ],
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$cantidad x \$${precioMostrar.toStringAsFixed(2)}',
                                                style: GoogleFonts.poppins(
                                                    color:
                                                        Colors.grey.shade700),
                                              ),
                                              if (esRegalo &&
                                                  _descripcionesRegalo
                                                      .containsKey(index)) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  '🎁 ${_descripcionesRegalo[index]}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.pink.shade700,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                              if (esPractica &&
                                                  _descripcionesPractica
                                                      .containsKey(index)) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  '📚 ${_descripcionesPractica[index]}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.blue.shade700,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          trailing: Text(
                                            '\$${totalMostrar.toStringAsFixed(2)}',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                              color: gradientEnd,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 0, 16, 8),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              InkWell(
                                                onTap: () async {
                                                  if (esRegalo) {
                                                    // Si ya es regalo, remover
                                                    setState(() {
                                                      _articulosRegalo
                                                          .remove(index);
                                                      _descripcionesRegalo
                                                          .remove(index);
                                                    });
                                                  } else {
                                                    // Si no es regalo, marcar y pedir descripción
                                                    setState(() {
                                                      _articulosRegalo
                                                          .add(index);
                                                      // Remover de práctica si estaba
                                                      _articulosPractica
                                                          .remove(index);
                                                      _descripcionesPractica
                                                          .remove(index);
                                                    });
                                                    await _mostrarDialogoDescripcion(
                                                        index, true);
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: esRegalo
                                                        ? Colors.pink.shade100
                                                        : Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('🎁',
                                                          style: TextStyle(
                                                              fontSize: 14)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Regalo',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 11,
                                                          fontWeight: esRegalo
                                                              ? FontWeight.w600
                                                              : FontWeight.w400,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () async {
                                                  if (esPractica) {
                                                    // Si ya es práctica, remover
                                                    setState(() {
                                                      _articulosPractica
                                                          .remove(index);
                                                      _descripcionesPractica
                                                          .remove(index);
                                                    });
                                                  } else {
                                                    // Si no es práctica, marcar y pedir descripción
                                                    setState(() {
                                                      _articulosPractica
                                                          .add(index);
                                                      // Remover de regalo si estaba
                                                      _articulosRegalo
                                                          .remove(index);
                                                      _descripcionesRegalo
                                                          .remove(index);
                                                    });
                                                    await _mostrarDialogoDescripcion(
                                                        index, false);
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: esPractica
                                                        ? Colors.blue.shade100
                                                        : Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('📚',
                                                          style: TextStyle(
                                                              fontSize: 14)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Práctica',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 11,
                                                          fontWeight: esPractica
                                                              ? FontWeight.w600
                                                              : FontWeight.w400,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ),

            // Total y acciones
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: const BoxDecoration(color: Color(0xFFF3F3F3)),
                  child: Column(
                    children: [
                      // Métodos de pago múltiples
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Métodos de Pago',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: gradientStart,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Efectivo
                            Row(
                              children: [
                                const Icon(Icons.attach_money, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Efectivo',
                                      style: GoogleFonts.poppins(fontSize: 14)),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: _montosControllers['Efectivo'],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    decoration: InputDecoration(
                                      prefixText: '\$',
                                      hintText: '0.00',
                                      hintStyle: GoogleFonts.poppins(
                                          color: Colors.grey.shade400),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Tarjeta
                            Row(
                              children: [
                                const Icon(Icons.credit_card, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Tarjeta',
                                          style: GoogleFonts.poppins(
                                              fontSize: 14)),
                                      if ((double.tryParse(
                                                  _montosControllers['Tarjeta']!
                                                      .text
                                                      .trim()) ??
                                              0.0) >
                                          0)
                                        SizedBox(
                                          width: 100,
                                          child: TextField(
                                            controller: _last4Ctrl,
                                            maxLength: 4,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.poppins(
                                                fontSize: 12),
                                            decoration: InputDecoration(
                                              counterText: '',
                                              hintText: 'Últimos 4',
                                              hintStyle: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade400),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            onChanged: (v) {
                                              if (v.length > 4) {
                                                _last4Ctrl.text =
                                                    v.substring(0, 4);
                                                _last4Ctrl.selection =
                                                    TextSelection.fromPosition(
                                                        const TextPosition(
                                                            offset: 4));
                                              }
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: _montosControllers['Tarjeta'],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    decoration: InputDecoration(
                                      prefixText: '\$',
                                      hintText: '0.00',
                                      hintStyle: GoogleFonts.poppins(
                                          color: Colors.grey.shade400),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (v) {
                                      setState(
                                          () {}); // Actualizar UI para mostrar campo de últimos 4
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Transferencia
                            Row(
                              children: [
                                const Icon(Icons.swap_horiz, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Transferencia',
                                          style: GoogleFonts.poppins(
                                              fontSize: 14)),
                                      if ((double.tryParse(_montosControllers[
                                                      'Transferencia']!
                                                  .text
                                                  .trim()) ??
                                              0.0) >
                                          0)
                                        SizedBox(
                                          width: 100,
                                          child: TextField(
                                            controller: _last4TransferenciaCtrl,
                                            maxLength: 4,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.poppins(
                                                fontSize: 12),
                                            decoration: InputDecoration(
                                              counterText: '',
                                              hintText: 'Últimos 4',
                                              hintStyle: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade400),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            onChanged: (v) {
                                              if (v.length > 4) {
                                                _last4TransferenciaCtrl.text =
                                                    v.substring(0, 4);
                                                _last4TransferenciaCtrl
                                                        .selection =
                                                    TextSelection.fromPosition(
                                                        const TextPosition(
                                                            offset: 4));
                                              }
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller:
                                        _montosControllers['Transferencia'],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    decoration: InputDecoration(
                                      prefixText: '\$',
                                      hintText: '0.00',
                                      hintStyle: GoogleFonts.poppins(
                                          color: Colors.grey.shade400),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (v) {
                                      setState(
                                          () {}); // Actualizar UI para mostrar campo de últimos 4
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Campo de descuento
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_offer,
                                    size: 20, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Descuento',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      )),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: _descuentoCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    decoration: InputDecoration(
                                      prefixText: '\$',
                                      hintText: '0.00',
                                      hintStyle: GoogleFonts.poppins(
                                          color: Colors.grey.shade400),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (v) {
                                      setState(() {}); // Actualizar total
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if ((double.tryParse(_descuentoCtrl.text.trim()) ??
                                    0.0) >
                                0) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _descripcionDescuentoCtrl,
                                style: GoogleFonts.poppins(fontSize: 13),
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'Motivo del descuento (opcional)',
                                  hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                      fontSize: 12),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.green.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.green.shade400,
                                        width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Column(
                        children: [
                          if ((double.tryParse(_descuentoCtrl.text.trim()) ??
                                  0.0) >
                              0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Subtotal',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    )),
                                Text('\$${_total.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    )),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Descuento',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.green.shade600,
                                    )),
                                Text(
                                    '-\$${(double.tryParse(_descuentoCtrl.text.trim()) ?? 0.0).toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.green.shade600,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: gradientStart,
                                  )),
                              Text('\$${_totalConDescuento.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: gradientEnd,
                                  )),
                            ],
                          ),
                        ],
                      ),
                      // Mensaje informativo sobre artículos gratis
                      if (_articulosRegalo.isNotEmpty ||
                          _articulosPractica.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Artículos marcados como Regalo 🎁 o Práctica 📚 no tienen costo',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _loading ? null : _loadAll,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: gradientStart),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('Actualizar',
                                  style: GoogleFonts.poppins(
                                    color: gradientStart,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _loading || _carrito.isEmpty
                                  ? null
                                  : _finalizarVenta,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gradientEnd,
                                disabledBackgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                elevation: 5,
                                shadowColor: Colors.grey.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Text('Finalizar Venta',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      )),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 65,
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              type: BottomNavigationBarType.fixed,
              currentIndex: 0,
              onTap: (index) {
                if (index == 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OptionsView()),
                  );
                } else if (index == 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MiPerfilView()),
                  );
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final IconData? icon;

  const _TextBox({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.pink.shade300, width: 1.5),
        ),
      ),
    );
  }
}

class _SaleItem {
  final String nombre;
  final double precio;
  final int cantidad;

  _SaleItem(
      {required this.nombre, required this.precio, required this.cantidad});

  double get total => precio * cantidad;
}
