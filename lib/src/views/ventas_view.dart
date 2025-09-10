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
import 'package:excel/excel.dart';
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

  // Pago
  String _metodoPago = 'Efectivo';
  final TextEditingController _last4Ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _last4Ctrl.dispose();
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

      final last4 = _last4Ctrl.text.trim();
      final body = jsonEncode({
        'id_encargado': userId,
        // API espera string con 2 decimales (según captura)
        'total_final': _asMoneyStr(_total),
        'productos': productos,
        'metodo_pago': _metodoPago.toLowerCase(),
        if (_metodoPago.toLowerCase() == 'tarjeta' && last4.length == 4)
          'ultimos4': last4,
        if (_metodoPago.toLowerCase() == 'tarjeta' && last4.length == 4)
          'tarjeta_ultimos4': last4,
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
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Método de pago:', style: GoogleFonts.poppins()),
                        Text(_metodoPago, style: GoogleFonts.poppins()),
                      ],
                    ),
                    if (_metodoPago.toLowerCase() == 'tarjeta' &&
                        _last4Ctrl.text.trim().isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tarjeta:', style: GoogleFonts.poppins()),
                          Text('**** ${_last4Ctrl.text.trim()}',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    const SizedBox(height: 8),
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

        // Opcional: limpiar carrito local después de vender
        setState(() {
          _carrito.clear();
          _loading = false;
          // Siempre limpiar los últimos 4 al finalizar una venta
          _last4Ctrl.clear();
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
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                                  final metodo =
                                      (v['metodo_pago'] ?? v['metodo'] ?? '')
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
                                final nombre = (p['nombre'] ?? '').toString();
                                final precio = (p['precio'] ?? '').toString();
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
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red.shade600,
                                      ),
                                      onPressed:
                                          _asInt(v['id'] ?? v['folio']) == null
                                              ? null
                                              : () async {
                                                  final idVenta = _asInt(
                                                      v['id'] ?? v['folio']);
                                                  if (idVenta == null) return;
                                                  final ok =
                                                      await showDialog<bool>(
                                                            context: context,
                                                            builder: (dctx) =>
                                                                AlertDialog(
                                                              title: Text(
                                                                  'Eliminar venta',
                                                                  style: GoogleFonts.poppins(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700)),
                                                              content: Text(
                                                                  '¿Seguro que deseas eliminar la venta #$idVenta? Esta acción no se puede deshacer.',
                                                                  style: GoogleFonts
                                                                      .poppins()),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          dctx,
                                                                          false),
                                                                  child: Text(
                                                                      'Cancelar',
                                                                      style: GoogleFonts
                                                                          .poppins()),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          dctx,
                                                                          true),
                                                                  child: Text(
                                                                      'Eliminar',
                                                                      style: GoogleFonts.poppins(
                                                                          color:
                                                                              Colors.red)),
                                                                ),
                                                              ],
                                                            ),
                                                          ) ??
                                                          false;
                                                  if (!ok) return;
                                                  await _eliminarVentaPorId(
                                                      idVenta);
                                                },
                                      icon: const Icon(Icons.delete_outline),
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
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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

      final excel = Excel.createExcel();
      const sheetName = 'Ventas';
      final sheet = excel[sheetName];
      // Asegurar que esta hoja sea la predeterminada y eliminar 'Sheet1' vacía
      try {
        excel.setDefaultSheet(sheetName);
      } catch (_) {}
      try {
        excel.delete('Sheet1');
      } catch (_) {}
      final headers = [
        'Folio',
        'Encargado',
        'Fecha',
        'MetodoPago',
        'Ultimos4',
        'Total',
        'Items',
        'Productos',
      ];
      sheet.appendRow(headers);

      // Estilos de encabezado
      final headerStyle = CellStyle(
        backgroundColorHex: '#F3E8FF', // lila claro
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontFamily: getFontFamily(FontFamily.Calibri),
      );
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        );
        cell.cellStyle = headerStyle;
      }

      // Anchos de columnas
      sheet.setColWidth(0, 10); // Folio
      sheet.setColWidth(1, 12); // Encargado
      sheet.setColWidth(2, 20); // Fecha
      sheet.setColWidth(3, 16); // MetodoPago
      sheet.setColWidth(4, 10); // Ultimos4
      sheet.setColWidth(5, 12); // Total
      sheet.setColWidth(6, 8); // Items
      sheet.setColWidth(7, 60); // Productos (largo)

      int appended = 0;
      for (final raw in _historial) {
        if (raw is! Map) continue; // aceptar cualquier Map<*,*>
        final m = raw as Map; // acceso laxo por clave

        final folio = m['folio'] ?? m['id'] ?? '';
        // encargado puede venir con otra clave; además formatear a string
        final encargadoVal = m['id_encargado'] ?? m['encargado'] ?? m['idUser'] ?? m['usuario'] ?? '';
        final encargado = encargadoVal?.toString() ?? '';
        // fecha puede venir en distintos campos; si es DateTime, formatear ISO corto
        dynamic fechaRaw = m['fecha'] ?? m['created_at'] ?? m['fecha_creacion'] ?? m['fechaVenta'] ?? '';
        String fecha;
        if (fechaRaw is DateTime) {
          fecha = fechaRaw.toIso8601String();
        } else {
          fecha = fechaRaw.toString();
        }
        // método de pago y últimos 4 con fallbacks
        final metodo = (m['metodo_pago'] ?? m['metodo'] ?? m['forma_pago'] ?? '').toString();
        final last4 = (m['ultimos4'] ?? m['tarjeta_ultimos4'] ?? m['last4'] ?? m['ultimos_digitos'] ?? '').toString();
        final total = m['total_final'] ?? m['total'] ?? '';

        // productos puede venir como List o como String JSON
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

        final items = productos.length;
        final productosStr = productos.map((p) {
          if (p is Map) {
            final n = p['nombre'] ?? '';
            final c = p['cantidad'] ?? '';
            final pr = p['precio'] ?? '';
            return '$n x$c @\$$pr';
          }
          return p.toString();
        }).join(' | ');

        sheet.appendRow([
          '$folio',
          '$encargado',
          '$fecha',
          '$metodo',
          '$last4',
          '$total',
          items,
          productosStr,
        ]);
        // Aplicar estilos por fila (zebra + alineaciones)
        final rowIndex = appended + 1; // encabezado en 0
        final zebraBg = (rowIndex % 2 == 1) ? '#FAF5FF' : '#FFFFFF';
        for (var c = 0; c < headers.length; c++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
          );
          if (c == 5) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: zebraBg,
              horizontalAlign: HorizontalAlign.Right,
              verticalAlign: VerticalAlign.Center,
              fontFamily: getFontFamily(FontFamily.Calibri),
            );
          } else if (c == 6) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: zebraBg,
              horizontalAlign: HorizontalAlign.Center,
              verticalAlign: VerticalAlign.Center,
              fontFamily: getFontFamily(FontFamily.Calibri),
            );
          } else if (c == 7) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: zebraBg,
              horizontalAlign: HorizontalAlign.Left,
              verticalAlign: VerticalAlign.Top,
              fontFamily: getFontFamily(FontFamily.Calibri),
            );
          } else {
            cell.cellStyle = CellStyle(
              backgroundColorHex: zebraBg,
              verticalAlign: VerticalAlign.Center,
              fontFamily: getFontFamily(FontFamily.Calibri),
            );
          }
        }
        appended++;
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('No se pudo generar el archivo');

      final fileName =
          'ventas_${DateTime.now().toIso8601String().replaceAll(':', '-')}.xlsx';
      final data = Uint8List.fromList(bytes);

      // Compartir/Enviar el archivo en lugar de descargar automáticamente
      await _shareExcel(data, fileName);

      if (!mounted) return;
      _showTopBar(
          'Excel listo',
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

  Future<void> _eliminarVentaPorId(int idVenta) async {
    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Venta #$idVenta eliminada',
                  style: GoogleFonts.poppins())),
        );
        // Refrescar historial en el sheet actual
        await _fetchHistorial();
        if (mounted) setState(() {});
      } else {
        throw Exception('Estado ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
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
                  // Método de pago y últimos 4
                  Row(
                    children: [
                      Flexible(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: _metodoPago,
                          decoration: InputDecoration(
                            labelText: 'Método de pago',
                            labelStyle: GoogleFonts.poppins(),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Efectivo',
                              child: Row(
                                children: [
                                  Icon(Icons.attach_money, size: 18),
                                  SizedBox(width: 8),
                                  Text('Efectivo'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Tarjeta',
                              child: Row(
                                children: [
                                  Icon(Icons.credit_card, size: 18),
                                  SizedBox(width: 8),
                                  Text('Tarjeta'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Transferencia',
                              child: Row(
                                children: [
                                  Icon(Icons.swap_horiz, size: 18),
                                  SizedBox(width: 8),
                                  Text('Transferencia'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _metodoPago = v;
                              if (_metodoPago != 'Tarjeta') {
                                _last4Ctrl.clear();
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: TextField(
                          controller: _last4Ctrl,
                          enabled: _metodoPago == 'Tarjeta',
                          maxLength: 4,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            counterText: '',
                            labelText: 'Últimos 4',
                            prefixIcon: const Icon(Icons.credit_card),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (v) {
                            if (v.length > 4) {
                              _last4Ctrl.text = v.substring(0, 4);
                              _last4Ctrl.selection = TextSelection.fromPosition(
                                  const TextPosition(offset: 4));
                            }
                          },
                        ),
                      ),
                    ],
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
