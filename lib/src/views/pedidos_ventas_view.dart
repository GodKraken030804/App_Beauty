import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'pedido_view.dart';
import 'mi_perfil_pedidos_view.dart';

class VentasPedidosView extends StatefulWidget {
  const VentasPedidosView({super.key});

  @override
  State<VentasPedidosView> createState() => _VentasPedidosViewState();
}

class _VentasPedidosViewState extends State<VentasPedidosView> {
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  bool _loading = true;
  String? _error;
  final List<Map<String, dynamic>> _carrito = [];
  final Map<int, String> _productoNombres = {};
  final Map<int, double> _productoPreciosUnitarios = {};
  final List<dynamic> _historial = [];
  bool _loadingHistorial = false;

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

  final Set<int> _articulosRegalo = {};
  final Set<int> _articulosPractica = {};

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
      }
    } catch (_) {}
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

        if (esRegalo) {
          productoData['es_regalo'] = true;
        }
        if (esPractica) {
          productoData['es_practica'] = true;
        }

        productos.add(productoData);
      }

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

      debugPrint('[POST Venta] Body JSON: $body');

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

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
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

        try {
          if (userId != null) {
            await _vaciarCarritoBackend(userId, token: token);
          }
        } catch (e) {
          debugPrint('No se pudo vaciar carrito backend: $e');
        }

        setState(() {
          _carrito.clear();
          _loading = false;
          _last4Ctrl.clear();
          _last4TransferenciaCtrl.clear();
          _descuentoCtrl.clear();
          _descripcionDescuentoCtrl.clear();
          for (var ctrl in _montosControllers.values) {
            ctrl.clear();
          }
          _articulosRegalo.clear();
          _articulosPractica.clear();
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

  Future<void> _actualizarCantidadesAsignadas(
      int? userId, List<Map<String, dynamic>> productos) async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final baseEmpresa = (dotenv.env['API_EMPRESA'] ?? '').trim();

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

        for (var prod in productos) {
          final idProducto = _asInt(prod['id_producto']);
          if (idProducto == null) continue;

          final cantidadVendida = prod['cantidad'] is num
              ? (prod['cantidad'] as num).toInt()
              : int.tryParse('${prod['cantidad']}') ?? 0;

          if (cantidadVendida <= 0) continue;

          debugPrint(
              '[Procesando] Producto ID: $idProducto, Cantidad vendida: $cantidadVendida');

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

            final nuevaCantidad = (cantidadActual - cantidadVendida)
                .clamp(0, double.infinity)
                .toInt();

            debugPrint(
                '[Calculando] Producto $idProducto: cantidad actual=$cantidadActual, vendida=$cantidadVendida, nueva=$nuevaCantidad');

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
          return;
        }
      }
    } catch (e) {
      debugPrint('No se pudo consultar carrito para vaciar: $e');
    }

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

    double totalVentas = 0.0;
    for (final venta in _historial) {
      if (venta is Map<String, dynamic>) {
        final totalStr =
            (venta['total_final'] ?? venta['total'] ?? '0.00').toString();
        final total = double.tryParse(totalStr) ?? 0.0;
        totalVentas += total;
      }
    }

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
                                    Text('Total: \$${total}',
                                        style: GoogleFonts.poppins(
                                            color: Colors.grey.shade700)),
                                    Builder(builder: (_) {
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
                                                ? '$metodoTexto **** $last4: \$${monto}'
                                                : '$metodoTexto: \$${monto}';

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
                                  ...productos
                                      .where((p) =>
                                          p is Map && p['nombre'] != null)
                                      .map((p) {
                                    final nombre =
                                        (p['nombre'] ?? '').toString();
                                    final precio =
                                        (p['precio'] ?? '').toString();
                                    final cantidad = p['cantidad'] ?? 0;

                                    String extras = '';
                                    if (p['es_regalo'] == true) extras += ' 🎁';
                                    if (p['es_practica'] == true)
                                      extras += ' 📚';

                                    return ListTile(
                                      dense: true,
                                      title: Text('$nombre$extras',
                                          style: GoogleFonts.poppins()),
                                      trailing: Text('$cantidad x \$${precio}',
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
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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

      final csvRows = <String>[];

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
        'Precios Unitarios',
        'Precios Venta',
        'Ganancia por Producto',
        'Ganancia Total',
        'Tipo (Venta/Regalo/Practica)',
      ];
      csvRows.add(headers.join(';'));

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
        debugPrint('Error al obtener precios unitarios: $e');
      }

      int appended = 0;
      double totalGeneral = 0.0;
      double gananciaGeneralTotal = 0.0;

      for (final raw in _historial) {
        if (raw is! Map) continue;
        final Map m = raw;

        final folio = (m['folio'] ?? m['id'] ?? '').toString();

        final encargadoVal = m['id_encargado'] ??
            m['encargado'] ??
            m['idUser'] ??
            m['usuario'] ??
            '';
        final encargado = encargadoVal?.toString() ?? '';

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
            fecha = fechaRaw.toIso8601String().substring(0, 10);
          } else {
            final fechaStr = fechaRaw.toString();
            try {
              final dt = DateTime.parse(fechaStr);
              fecha = dt.toIso8601String().substring(0, 10);
            } catch (_) {
              fecha =
                  fechaStr.length > 10 ? fechaStr.substring(0, 10) : fechaStr;
            }
          }
        }

        final total = (m['total_final'] ?? m['total'] ?? '0.00').toString();
        final totalNum = double.tryParse(total) ?? 0.0;
        totalGeneral += totalNum;

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

        descripcionDescuento = (m['descripcion_descuento'] ?? '').toString();

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

        final nombresProductos = <String>[];
        final cantidades = <String>[];
        final precios = <String>[];
        final preciosUnitariosStr = <String>[];
        final gananciasStr = <String>[];
        final tipos = <String>[];

        double gananciaVenta = 0.0;

        String efectivo = '-';
        String tarjeta = '-';
        String tarjetaLast4 = '-';
        String transferencia = '-';
        String transferenciaLast4 = '-';

        for (var item in productosRaw) {
          if (item is Map) {
            if (item['nombre'] != null) {
              nombresProductos.add((item['nombre'] ?? 'Producto').toString());
              final cantidadItem =
                  int.tryParse((item['cantidad'] ?? '0').toString()) ?? 0;
              cantidades.add(cantidadItem.toString());
              final precioVenta =
                  double.tryParse((item['precio'] ?? '0.00').toString()) ?? 0.0;
              precios.add(precioVenta.toStringAsFixed(2));

              final idProducto = _asInt(item['id_producto'] ??
                  item['idproduc'] ??
                  item['producto_id']);
              final precioUnitario = (idProducto != null &&
                      preciosUnitarios.containsKey(idProducto))
                  ? preciosUnitarios[idProducto]!
                  : 0.0;
              preciosUnitariosStr.add(precioUnitario.toStringAsFixed(2));

              final gananciaPorProducto =
                  (precioVenta - precioUnitario) * cantidadItem;
              gananciasStr.add(gananciaPorProducto.toStringAsFixed(2));

              String tipo = 'Venta';
              if (item['es_regalo'] == true) {
                tipo = 'Regalo';
              } else if (item['es_practica'] == true) {
                tipo = 'Practica';
              } else {
                gananciaVenta += gananciaPorProducto;
              }
              tipos.add(tipo);
            } else if (item['tipo'] == 'descuento' &&
                item['descuento'] != null) {
              final descuentoItem = item['descuento'].toString();
              final parsedDesc = double.tryParse(descuentoItem);
              if (parsedDesc != null && parsedDesc > 0) {
                descuento = parsedDesc.toStringAsFixed(2);
              }
              if (item['descripcion'] != null) {
                descripcionDescuento = item['descripcion'].toString();
              }
            } else if (item['metodo'] != null) {
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

        final productosStr = nombresProductos.join(' | ');
        final cantidadesStr = cantidades.join(' | ');
        final preciosStr = precios.join(' | ');
        final preciosUnitariosStrJoined = preciosUnitariosStr.join(' | ');
        final gananciasStrJoined = gananciasStr.join(' | ');
        final tiposStr = tipos.join(' | ');

        gananciaGeneralTotal += gananciaVenta;

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
          tiposStr.isEmpty ? '-' : tiposStr,
        ];
        csvRows.add(row.join(';'));
        appended++;
      }

      if (appended > 0) {
        csvRows.add('');
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
          '\$${gananciaGeneralTotal.toStringAsFixed(2)}',
          '',
        ];
        csvRows.add(rowTotales.join(';'));
      }

      final csvContent = csvRows.join('\r\n');
      final bomUtf8 = [0xEF, 0xBB, 0xBF];
      final contentBytes = utf8.encode(csvContent);
      final bytes = Uint8List.fromList([...bomUtf8, ...contentBytes]);

      final fileName =
          'ventas_${DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19)}.csv';

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

  Future<void> _shareFile(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
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

  Future<void> _eliminarVentaPorId(int idVenta,
      [StateSetter? setModalState, BuildContext? modalContext]) async {
    try {
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Venta #$idVenta eliminada',
                  style: GoogleFonts.poppins())),
        );

        if (modalContext != null && Navigator.canPop(modalContext)) {
          Navigator.pop(modalContext);
        }

        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          await _showHistorialSheet();
        }
      } else {
        throw Exception('Estado ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;

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
                                          subtitle: Text(
                                            '$cantidad x \$${precioMostrar.toStringAsFixed(2)}',
                                            style: GoogleFonts.poppins(
                                                color: Colors.grey.shade700),
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
                                                onTap: () {
                                                  setState(() {
                                                    if (esRegalo) {
                                                      _articulosRegalo
                                                          .remove(index);
                                                    } else {
                                                      _articulosRegalo
                                                          .add(index);
                                                    }
                                                  });
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
                                                onTap: () {
                                                  setState(() {
                                                    if (esPractica) {
                                                      _articulosPractica
                                                          .remove(index);
                                                    } else {
                                                      _articulosPractica
                                                          .add(index);
                                                    }
                                                  });
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
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: const BoxDecoration(color: Color(0xFFF3F3F3)),
                  child: Column(
                    children: [
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
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
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
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
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
                                      setState(() {});
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
                    MaterialPageRoute(builder: (_) => const PedidoView()),
                  );
                } else if (index == 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MiPerfilPedidosView()),
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

// (Sin clases auxiliares no utilizadas)
