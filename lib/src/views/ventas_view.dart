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

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _last4Ctrl.dispose();
    for (var ctrl in _montosControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  double get _total => _carrito.fold(0.0, (a, it) {
        final v = it['total'];
        return a + (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);
      });
  double _round2(double v) => double.parse(v.toStringAsFixed(2));
  String _asMoneyStr(num v) => v.toDouble().toStringAsFixed(2);
  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> _fetchProductos() async {
    try {
      final uri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/producto');
      final res = await http.get(uri);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        _productoNombres.clear();
        if (data is List) {
          for (final el in data) {
            if (el is Map<String, dynamic>) {
              final id = _asInt(el['id']);
              final nombre = (el['nombre'] ?? '').toString();
              if (id != null && nombre.isNotEmpty) {
                _productoNombres[id] = nombre;
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
        metodosPagoActivos.add({
          'metodo': metodo.toLowerCase(),
          'monto': _round2(monto),
          if (metodo == 'Tarjeta' && _last4Ctrl.text.trim().length == 4)
            'ultimos4': _last4Ctrl.text.trim(),
        });
      }
    }

    // Validar que el total de pagos coincida con el total de la venta
    if ((totalPagos - _total).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade400,
          content: Text(
              'El total de pagos (\$${totalPagos.toStringAsFixed(2)}) no coincide con el total de la venta (\$${_total.toStringAsFixed(2)})',
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

    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final int? userId =
          token != null ? _asInt(JwtDecoder.decode(token)['id']) : null;

      // Armar productos con nombre, cantidad y precio unitario
      final productos = _carrito.map((it) {
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
        final precio = cantidad > 0 ? total / cantidad : 0.0;
        return {
          if (idProd != null) 'id_producto': idProd,
          'nombre': nombre,
          'cantidad': cantidad,
          'precio': _round2(precio),
        };
      }).toList();

      final body = jsonEncode({
        'id_encargado': userId,
        'total_final': _asMoneyStr(_total),
        'productos': productos,
        'metodos_pago': metodosPagoActivos,
      });

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

      if (res.statusCode >= 200 && res.statusCode < 300) {
        try {
          debugPrint('[POST Venta] OK via ${uri.toString()}');
        } catch (_) {}
        Map<String, dynamic>? respJson;
        try {
          respJson = jsonDecode(res.body);
        } catch (_) {}

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
                    ...metodosPagoActivos.map((mp) {
                      final metodo = mp['metodo'] ?? '';
                      final monto = mp['monto'] ?? 0.0;
                      final last4 = mp['ultimos4'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              metodo == 'tarjeta' && last4.isNotEmpty
                                  ? 'Tarjeta **** $last4'
                                  : '${metodo[0].toUpperCase()}${metodo.substring(1)}',
                              style: GoogleFonts.poppins(),
                            ),
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
                    ...productos.map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(
                                      '${p['nombre']} x${p['cantidad']}',
                                      style: GoogleFonts.poppins())),
                              Text(
                                  '\$${(p['precio'] as double).toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700)),
                        Text('\$${_round2(_total).toStringAsFixed(2)}',
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
          for (var ctrl in _montosControllers.values) {
            ctrl.clear();
          }
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

  // Elimina del backend los items del carrito del encargado dado.
  // Estrategia:
  // 1) GET api/v1/carrito -> localizar items del usuario y DELETE api/v1/carrito/{id}
  // 2) Si no hay IDs, intentar un DELETE masivo por encargado: api/v1/carrito/encargado/{userId}
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
                                      // Verificar si tiene métodos de pago múltiples
                                      if (v['metodos_pago'] != null &&
                                          v['metodos_pago'] is List) {
                                        final metodosList =
                                            v['metodos_pago'] as List;
                                        if (metodosList.isEmpty) {
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
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            ...metodosList.map((mp) {
                                              if (mp is Map) {
                                                final metodo =
                                                    (mp['metodo'] ?? '')
                                                        .toString();
                                                final monto =
                                                    (mp['monto'] ?? '')
                                                        .toString();
                                                final last4 =
                                                    (mp['ultimos4'] ?? '')
                                                        .toString();

                                                final metodoTexto = metodo
                                                        .isEmpty
                                                    ? 'N/D'
                                                    : metodo[0].toUpperCase() +
                                                        metodo.substring(1);

                                                final pagoTexto = metodo
                                                                .toLowerCase() ==
                                                            'tarjeta' &&
                                                        last4.isNotEmpty
                                                    ? '$metodoTexto **** $last4: \$$monto'
                                                    : '$metodoTexto: \$$monto';

                                                return Text(
                                                  pagoTexto,
                                                  style: GoogleFonts.poppins(
                                                      color:
                                                          Colors.grey.shade700,
                                                      fontSize: 11),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            }),
                                          ],
                                        );
                                      }

                                      // Fallback: método de pago único (compatibilidad)
                                      final metodo = (v['metodo_pago'] ??
                                              v['metodo'] ??
                                              '')
                                          .toString();
                                      final last4 = (v['ultimos4'] ??
                                              v['tarjeta_ultimos4'] ??
                                              v['last4'] ??
                                              '')
                                          .toString();
                                      if (metodo.isEmpty && last4.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(
                                        metodo.toLowerCase() == 'tarjeta' &&
                                                last4.isNotEmpty
                                            ? 'Pago: Tarjeta **** $last4'
                                            : 'Pago: ${metodo.isEmpty ? 'N/D' : metodo}',
                                        style: GoogleFonts.poppins(
                                            color: Colors.grey.shade700,
                                            fontSize: 12),
                                      );
                                    }),
                                  ],
                                ),
                                children: [
                                  ...productos.map((p) {
                                    final nombre =
                                        (p['nombre'] ?? '').toString();
                                    final precio =
                                        (p['precio'] ?? '').toString();
                                    final cantidad = p['cantidad'] ?? 0;
                                    return ListTile(
                                      dense: true,
                                      title: Text(nombre,
                                          style: GoogleFonts.poppins()),
                                      trailing: Text('${cantidad} x \$$precio',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600)),
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
        'Metodos de Pago',
        'Montos',
        'Tarjeta Ultimos 4',
        'Total',
        'Productos',
        'Cantidades',
        'Precios Unitarios',
      ];
      csvRows.add(headers.join(';')); // Usar punto y coma como delimitador

      int appended = 0;
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

        // Fecha
        dynamic fechaRaw = m['fecha'] ??
            m['created_at'] ??
            m['fecha_creacion'] ??
            m['fechaVenta'] ??
            '';
        String fecha;
        if (fechaRaw is DateTime) {
          fecha = fechaRaw.toIso8601String();
        } else {
          fecha = fechaRaw.toString();
        }

        // Métodos de pago (puede ser múltiple o único)
        String metodosPago = '';
        String montosPago = '';
        String tarjetaLast4 = '';

        // Verificar si tiene métodos de pago múltiples
        if (m['metodos_pago'] != null && m['metodos_pago'] is List) {
          final metodosList = m['metodos_pago'] as List;
          final metodos = <String>[];
          final montos = <String>[];

          for (var mp in metodosList) {
            if (mp is Map) {
              final metodo = (mp['metodo'] ?? '').toString();
              final monto = (mp['monto'] ?? '').toString();
              metodos.add(metodo.isEmpty
                  ? 'N/D'
                  : metodo[0].toUpperCase() + metodo.substring(1));
              montos.add(monto); // Sin símbolo $

              // Capturar últimos 4 de tarjeta
              if (metodo.toLowerCase() == 'tarjeta' && mp['ultimos4'] != null) {
                tarjetaLast4 = mp['ultimos4'].toString();
              }
            }
          }

          metodosPago = metodos.join(' + ');
          montosPago = montos.join(' + ');
        } else {
          // Método de pago único (compatibilidad con versiones anteriores)
          final metodo =
              (m['metodo_pago'] ?? m['metodo'] ?? m['forma_pago'] ?? '')
                  .toString();
          metodosPago = metodo.isEmpty
              ? 'N/D'
              : metodo[0].toUpperCase() + metodo.substring(1);
          montosPago =
              '${m['total_final'] ?? m['total'] ?? '0.00'}'; // Sin símbolo $
          tarjetaLast4 =
              (m['ultimos4'] ?? m['tarjeta_ultimos4'] ?? m['last4'] ?? '')
                  .toString();
        }

        final total = (m['total_final'] ?? m['total'] ?? '0.00').toString();

        // Productos
        dynamic rawProds = m['productos'];
        List productos;
        if (rawProds is List) {
          productos = rawProds;
        } else if (rawProds is String) {
          try {
            final decoded = jsonDecode(rawProds);
            productos = (decoded is List) ? decoded : [];
          } catch (_) {
            productos = [];
          }
        } else {
          productos = [];
        }

        final nombresProductos = <String>[];
        final cantidades = <String>[];
        final precios = <String>[];

        for (var p in productos) {
          if (p is Map) {
            nombresProductos.add((p['nombre'] ?? 'Producto').toString());
            cantidades.add((p['cantidad'] ?? '0').toString());
            precios.add((p['precio'] ?? '0.00').toString()); // Sin símbolo $
          }
        }

        final productosStr =
            nombresProductos.join(' | '); // Usar | en lugar de ;
        final cantidadesStr = cantidades.join(' | ');
        final preciosStr = precios.join(' | ');

        // Agregar fila al CSV
        final row = [
          folio,
          encargado,
          fecha,
          metodosPago,
          montosPago,
          tarjetaLast4.isEmpty ? '-' : '****$tarjetaLast4',
          total,
          productosStr.isEmpty ? 'Sin productos' : productosStr,
          cantidadesStr.isEmpty ? '-' : cantidadesStr,
          preciosStr.isEmpty ? '-' : preciosStr,
        ];
        csvRows.add(row.join(';')); // Usar punto y coma como delimitador
        appended++;
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
                                    child: ListTile(
                                      title: Text(
                                        nombreProd,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        '$cantidad x \$${precioU.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                            color: Colors.grey.shade700),
                                      ),
                                      trailing: Text(
                                        '\$${total.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          color: gradientEnd,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ),

            // Total y acciones
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(color: Color(0xFFF3F3F3)),
              child: Column(
                children: [
                  // Métodos de pago múltiples
                  Container(
                    padding: const EdgeInsets.all(12),
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
                        const SizedBox(height: 8),
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
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Tarjeta
                        Row(
                          children: [
                            const Icon(Icons.credit_card, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tarjeta',
                                      style: GoogleFonts.poppins(fontSize: 14)),
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
                                        style:
                                            GoogleFonts.poppins(fontSize: 12),
                                        decoration: InputDecoration(
                                          counterText: '',
                                          hintText: 'Últimos 4',
                                          hintStyle: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey.shade400),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 4),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                        onChanged: (v) {
                                          if (v.length > 4) {
                                            _last4Ctrl.text = v.substring(0, 4);
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
                                  contentPadding: const EdgeInsets.symmetric(
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
                        const SizedBox(height: 8),
                        // Transferencia
                        Row(
                          children: [
                            const Icon(Icons.swap_horiz, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Transferencia',
                                  style: GoogleFonts.poppins(fontSize: 14)),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _montosControllers['Transferencia'],
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
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: gradientStart,
                          )),
                      Text('\$${_total.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: gradientEnd,
                          )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _loadAll,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
        child: SizedBox(
          height: 70,
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
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
