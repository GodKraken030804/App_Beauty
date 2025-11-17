import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_beauty/src/views/options_view.dart';
import 'package:app_beauty/src/views/mi_perfil_view.dart';
import 'package:app_beauty/src/views/pedido_view.dart';
import 'package:app_beauty/src/views/mi_perfil_pedidos_view.dart';
import 'package:app_beauty/src/views/pedidos_ventas_view.dart';
import 'package:google_fonts/google_fonts.dart';
// Removed exports & menu dependencies as per new requirements

class ProductosExcelView extends StatefulWidget {
  final bool pedidoMode;
  const ProductosExcelView({super.key, this.pedidoMode = false});

  @override
  State<ProductosExcelView> createState() => _ProductosExcelViewState();
}

class _ProductosExcelViewState extends State<ProductosExcelView> {
  List productosAsignados = [];
  final List<Color> gradientColors = const [
    Color(0xFFF26AB6),
    Color(0xFFAA57EC)
  ];

  // UI state: search & sort
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _SortMode _sortMode = _SortMode.alpha;

  // Favorites
  final String _favKey = 'inventario_favoritos';
  Set<int> _favoriteIds = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchProductosAsignados();
    _loadFavorites();
  }

  Future<void> _fetchProductosAsignados() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final decoded = JwtDecoder.decode(token);
    final dynamic userIdRaw = decoded['id'];
    final int userId = userIdRaw is int
        ? userIdRaw
        : int.tryParse(userIdRaw?.toString() ?? '') ?? -1;
    final asignadoUri =
        Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/asignado');
    final productoUri =
        Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/producto');

    try {
      final asignadoRes = await http.get(asignadoUri);
      final productoRes = await http.get(productoUri);

      if (asignadoRes.statusCode == 200 && productoRes.statusCode == 200) {
        final asignaciones = jsonDecode(asignadoRes.body);
        final productosAll = jsonDecode(productoRes.body);

        // Asegura comparación robusta (id como int o string)
        final asignadosUsuario = asignaciones.where((a) {
          final dynamic aid = a['iduser'];
          final int aidInt =
              aid is int ? aid : int.tryParse(aid?.toString() ?? '') ?? -999999;
          return aidInt == userId;
        }).toList();
        final Map<int, dynamic> productosAgrupados = {};

        for (var a in asignadosUsuario) {
          // Normaliza IDs y cantidades
          final dynamic pidRaw = a['idproduc'];
          final int pid = pidRaw is int
              ? pidRaw
              : int.tryParse(pidRaw?.toString() ?? '') ?? -1;
          final producto = productosAll.firstWhere(
            (p) {
              final dynamic pIdRaw = p['id'];
              final int pId = pIdRaw is int
                  ? pIdRaw
                  : int.tryParse(pIdRaw?.toString() ?? '') ?? -2;
              return pId == pid;
            },
            orElse: () => null,
          );
          if (producto != null) {
            final dynamic pIdRaw = producto['id'];
            final int pId = pIdRaw is int
                ? pIdRaw
                : int.tryParse(pIdRaw?.toString() ?? '') ?? -3;
            final int cantAsig = (a['cantidad'] is num)
                ? (a['cantidad'] as num).toInt()
                : int.tryParse(a['cantidad']?.toString() ?? '') ?? 0;
            if (productosAgrupados.containsKey(pId)) {
              final prev = productosAgrupados[pId]['cantidad_asignada'] ?? 0;
              final prevInt =
                  prev is num ? prev.toInt() : int.tryParse('$prev') ?? 0;
              productosAgrupados[pId]['cantidad_asignada'] = prevInt + cantAsig;
            } else {
              final nuevo = Map<String, dynamic>.from(producto);
              nuevo['cantidad_asignada'] = cantAsig;
              productosAgrupados[pId] = nuevo;
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

  // Derive filtered + sorted list without mutating original data
  List _filteredSortedProductos() {
    List list = productosAsignados;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
              (p) => (p['nombre']?.toString().toLowerCase() ?? '').contains(q))
          .toList();
    }
    if (_sortMode == _SortMode.favorites) {
      // filter only favorites; order alphabetically for consistency
      list = list
          .where((p) => _favoriteIds.contains((p['id'] ?? -1) is int
              ? p['id'] as int
              : int.tryParse(p['id']?.toString() ?? '') ?? -1))
          .toList();
      list.sort((a, b) {
        final na = (a['nombre'] ?? '').toString().toLowerCase();
        final nb = (b['nombre'] ?? '').toString().toLowerCase();
        return na.compareTo(nb);
      });
    } else {
      list.sort((a, b) {
        if (_sortMode == _SortMode.priceAsc) {
          final pa = (a['precio'] is num)
              ? (a['precio'] as num).toDouble()
              : double.tryParse(a['precio']?.toString() ?? '') ?? 0.0;
          final pb = (b['precio'] is num)
              ? (b['precio'] as num).toDouble()
              : double.tryParse(b['precio']?.toString() ?? '') ?? 0.0;
          return pa.compareTo(pb);
        } else {
          final na = (a['nombre'] ?? '').toString().toLowerCase();
          final nb = (b['nombre'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        }
      });
    }
    return list;
  }

  // ===================== Favorites =====================
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favKey) ?? <String>[];
    setState(() {
      _favoriteIds =
          list.map((e) => int.tryParse(e) ?? -1).where((e) => e != -1).toSet();
    });
  }

  Future<void> _toggleFavorite(int id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
    await prefs.setStringList(
        _favKey, _favoriteIds.map((e) => e.toString()).toList());
  }

  // ===================== UI Helpers =====================
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
        controller: _searchController,
        style: GoogleFonts.poppins(),
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
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
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close, color: Colors.grey),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSortRow() {
    Widget seg(String text, IconData icon, _SortMode mode,
        {BorderRadius? radius}) {
      final bool selected = _sortMode == mode;
      return Expanded(
        child: InkWell(
          borderRadius: radius ?? BorderRadius.zero,
          onTap: () => setState(() => _sortMode = mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: radius ?? BorderRadius.zero,
              // Overlay para estados no seleccionados (blanco translúcido)
              color: selected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.15),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(text,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            seg('Precio', Icons.trending_up, _SortMode.priceAsc,
                radius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16))),
            // separador
            Container(width: 1, height: 36, color: Colors.white24),
            seg('Alfabético', Icons.sort_by_alpha, _SortMode.alpha),
            Container(width: 1, height: 36, color: Colors.white24),
            seg('Favoritos', Icons.star, _SortMode.favorites,
                radius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16))),
          ],
        ),
      ),
    );
  }

  // Product tile builder
  Widget _buildProductTile(Map producto) {
    final imagenNombre = (producto['imagen'] ?? '').toString().split('/').last;
    final imagenUrl = "${dotenv.env['API_IMAGES']}imagen/$imagenNombre";
    final cantidad = producto['cantidad_asignada'] ?? 0;
    final cantidadInt = cantidad is num
        ? cantidad.toInt()
        : int.tryParse(cantidad.toString()) ?? 0;
    final nombre = producto['nombre'] ?? '';
    final idRaw = producto['id'];
    final int id =
        (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? -1;
    final isFav = _favoriteIds.contains(id);

    return _ProductTile(
      nombre: nombre.toString(),
      imagenUrl: imagenUrl,
      cantidad: cantidadInt,
      precio: producto['precio'] != null ? '${producto['precio']}' : null,
      precioUnitario: producto['precioUnitario'] != null
          ? '${producto['precioUnitario']}'
          : null,
      isFavorite: isFav,
      onToggleFavorite: () => _toggleFavorite(id),
      gradientColors: gradientColors,
      onTap: () => _onTapProducto(producto),
      lowStock: cantidadInt > 0 && cantidadInt < 5, // Indica stock bajo
      outOfStock: cantidadInt == 0, // Indica sin stock
    );
  }

  Future<void> _onTapProducto(Map producto) async {
    final int disponible = (producto['cantidad_asignada'] is num)
        ? (producto['cantidad_asignada'] as num).toInt()
        : int.tryParse('${producto['cantidad_asignada']}') ?? 0;
    if (disponible <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Sin stock disponible'),
            backgroundColor: gradientColors.first),
      );
      return;
    }

    // Pre-diálogo estético con logo, estilo similar a Inventario_Admin_view
    final continuar = await _mostrarDialogoProductoEstetico(producto) ?? false;
    if (!continuar) return;

    int cantidad = 1;
    // Nueva vista para elegir cantidad (sin tocar endpoints)
    final cantidadElegida = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => _CantidadPage(max: disponible, colors: gradientColors),
      ),
    );
    if (cantidadElegida == null) return;
    cantidad = cantidadElegida;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = token != null ? JwtDecoder.decode(token)['id'] : null;
      final double precio = (producto['precio'] is num)
          ? (producto['precio'] as num).toDouble()
          : double.tryParse('${producto['precio']}') ?? 0.0;
      final total = (precio * cantidad);

      final body = jsonEncode({
        'id_encargado': userId,
        'id_producto': producto['id'],
        'cantidad': cantidad,
        'total': double.parse(total.toStringAsFixed(2)),
      });

      // Enviar al carrito del backend de empresa
      final uri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/carrito');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // ✅ Actualizar cantidad local después de agregar exitosamente al carrito
        await _actualizarCantidadLocal(producto, cantidad);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Producto agregado a ventas'),
            backgroundColor: gradientColors.last,
          ),
        );
        if (widget.pedidoMode) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VentasPedidosView()),
          );
        } else {
          Navigator.pushNamed(context, '/ventas');
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar al carrito (${res.statusCode})'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  /// Actualiza la cantidad asignada localmente y en el backend después de agregar al carrito
  Future<void> _actualizarCantidadLocal(
      Map producto, int cantidadVendida) async {
    // 1. Actualizar estado local inmediatamente
    setState(() {
      // Buscar el producto en la lista local y restar la cantidad
      final index = productosAsignados.indexWhere((p) {
        final pIdRaw = p['id'];
        final prodIdRaw = producto['id'];
        final pId = pIdRaw is int
            ? pIdRaw
            : int.tryParse(pIdRaw?.toString() ?? '') ?? -1;
        final prodId = prodIdRaw is int
            ? prodIdRaw
            : int.tryParse(prodIdRaw?.toString() ?? '') ?? -2;
        return pId == prodId;
      });

      if (index != -1) {
        final cantidadActual =
            productosAsignados[index]['cantidad_asignada'] ?? 0;
        final cantidadActualInt = cantidadActual is num
            ? cantidadActual.toInt()
            : int.tryParse(cantidadActual.toString()) ?? 0;

        final nuevaCantidad = (cantidadActualInt - cantidadVendida)
            .clamp(0, double.infinity)
            .toInt();
        productosAsignados[index]['cantidad_asignada'] = nuevaCantidad;

        // Mostrar mensaje si el producto se quedó sin stock
        if (nuevaCantidad == 0) {
          debugPrint(
              '⚠️ Producto "${productosAsignados[index]['nombre']}" sin stock');
        }
      }
    });

    // 2. Actualizar en el backend de forma asíncrona
    await _actualizarCantidadBackend(producto, cantidadVendida);
  }

  /// Actualiza la cantidad en la tabla 'asignado' del backend
  Future<void> _actualizarCantidadBackend(
      Map producto, int cantidadVendida) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final decoded = JwtDecoder.decode(token);
      final dynamic userIdRaw = decoded['id'];
      final int userId = userIdRaw is int
          ? userIdRaw
          : int.tryParse(userIdRaw?.toString() ?? '') ?? -1;

      final dynamic productoIdRaw = producto['id'];
      final int productoId = productoIdRaw is int
          ? productoIdRaw
          : int.tryParse(productoIdRaw?.toString() ?? '') ?? -1;

      // Obtener todos los registros de asignación
      final asignadoUri =
          Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/asignado');
      final getRes = await http.get(asignadoUri);

      if (getRes.statusCode == 200) {
        final asignaciones = jsonDecode(getRes.body) as List;

        // Buscar registros específicos para este usuario y producto
        final asignadosRelacionados = asignaciones.where((a) {
          final dynamic aid = a['iduser'];
          final dynamic pid = a['idproduc'];
          final int aidInt =
              aid is int ? aid : int.tryParse(aid?.toString() ?? '') ?? -999999;
          final int pidInt =
              pid is int ? pid : int.tryParse(pid?.toString() ?? '') ?? -999999;
          return aidInt == userId && pidInt == productoId;
        }).toList();

        if (asignadosRelacionados.isEmpty) {
          debugPrint(
              '⚠️ No se encontró asignación para usuario $userId y producto $productoId');
          return;
        }

        // Estrategia: Actualizar el primer registro encontrado restando la cantidad vendida
        final asignacionActual = asignadosRelacionados.first;
        final dynamic idAsignacionRaw = asignacionActual['id'];
        final int? idAsignacion = idAsignacionRaw is int
            ? idAsignacionRaw
            : int.tryParse(idAsignacionRaw?.toString() ?? '');

        final cantidadActualAsignada = asignacionActual['cantidad'] ?? 0;
        final cantidadActualInt = cantidadActualAsignada is num
            ? cantidadActualAsignada.toInt()
            : int.tryParse(cantidadActualAsignada.toString()) ?? 0;

        final nuevaCantidad = (cantidadActualInt - cantidadVendida)
            .clamp(0, double.infinity)
            .toInt();

        // Intentar actualizar con PUT (si el endpoint existe) o DELETE + POST
        if (idAsignacion != null) {
          // Opción 1: Intentar PUT
          final putUri = Uri.parse(
              '${dotenv.env['API_EMPRESA']}api/v1/asignado/$idAsignacion');
          final putRes = await http.put(
            putUri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'iduser': userId,
              'idproduc': productoId,
              'cantidad': nuevaCantidad,
            }),
          );

          if (putRes.statusCode >= 200 && putRes.statusCode < 300) {
            debugPrint(
                '✅ Cantidad actualizada en backend: $nuevaCantidad unidades');
            return;
          }

          // Si PUT no funciona, intentar DELETE + POST
          debugPrint(
              '⚠️ PUT falló (${putRes.statusCode}), intentando DELETE + POST...');

          final deleteUri = Uri.parse(
              '${dotenv.env['API_EMPRESA']}api/v1/asignado/$idAsignacion');
          final deleteRes = await http.delete(deleteUri, headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          });

          if (deleteRes.statusCode >= 200 && deleteRes.statusCode < 300) {
            // Si la nueva cantidad es > 0, crear un nuevo registro
            if (nuevaCantidad > 0) {
              final postRes = await http.post(
                asignadoUri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'iduser': userId,
                  'idproduc': productoId,
                  'cantidad': nuevaCantidad,
                }),
              );

              if (postRes.statusCode >= 200 && postRes.statusCode < 300) {
                debugPrint(
                    '✅ Cantidad actualizada en backend (DELETE + POST): $nuevaCantidad unidades');
              } else {
                debugPrint(
                    '⚠️ Error al crear nuevo registro: ${postRes.statusCode}');
              }
            } else {
              debugPrint('✅ Registro eliminado (cantidad = 0)');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error al actualizar cantidad en backend: $e');
      // No mostramos error al usuario para no interrumpir el flujo, ya que el local está actualizado
    }
  }

  Future<bool?> _mostrarDialogoProductoEstetico(Map producto) async {
    final nombre = (producto['nombre'] ?? '').toString();
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Image.asset('assets/images/Logo.png',
                      height: 90, fit: BoxFit.contain),
                ),
                const SizedBox(height: 8),
                Text(nombre,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Text('¿Deseas elegir cuántas piezas agregar al carrito?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.grey[700])),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: gradientColors.first),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancelar',
                            style: GoogleFonts.poppins(
                                color: gradientColors.first,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradientColors),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('Elegir cantidad',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
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
      body: Column(
        children: [
          // Top gradient bar
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
          // Header: Logo, title, search, sort
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Inventario',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: gradientColors.first,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Botón discreto para "Armar paquete"
                    Tooltip(
                      message: 'Armar paquete',
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: gradientColors.first,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _abrirArmarPaquete,
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: Text('Armar',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 10),
                _buildSortRow(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RefreshIndicator(
                color: gradientColors.first,
                onRefresh: _fetchProductosAsignados,
                child: productosAsignados.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 140),
                          Center(child: CircularProgressIndicator()),
                          SizedBox(height: 12),
                        ],
                      )
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _filteredSortedProductos().length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) {
                          final producto = _filteredSortedProductos()[index];
                          return _buildProductTile(producto);
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
      // Botón flotante con opciones de descargar y enviar
      floatingActionButton: FloatingActionButton(
        backgroundColor: gradientColors.first,
        onPressed: () {
          _mostrarMenuOpciones();
        },
        child: const Icon(Icons.download, color: Colors.white),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
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
                  if (widget.pedidoMode) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const PedidoView()),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const OptionsView()),
                    );
                  }
                } else if (index == 1) {
                  if (widget.pedidoMode) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MiPerfilPedidosView()),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MiPerfilView()),
                    );
                  }
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

// ===================== Paquetes =====================
class _PaqueteItem {
  final Map producto;
  final int cantidad;
  _PaqueteItem({required this.producto, required this.cantidad});
}

extension on _ProductosExcelViewState {
  Future<void> _abrirArmarPaquete() async {
    if (productosAsignados.isEmpty) return;
    final seleccion = await Navigator.push<List<_PaqueteItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => _ArmarPaquetePage(
          productos: productosAsignados,
          colors: gradientColors,
        ),
      ),
    );
    if (seleccion == null || seleccion.isEmpty) return;
    await _agregarPaqueteAlCarrito(seleccion);
  }

  Future<void> _agregarPaqueteAlCarrito(List<_PaqueteItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;
      final userId = JwtDecoder.decode(token)['id'];

      double totalPaquete = 0.0;
      for (final it in items) {
        final producto = it.producto;
        final int cant = it.cantidad;
        final double precio = (producto['precio'] is num)
            ? (producto['precio'] as num).toDouble()
            : double.tryParse('${producto['precio']}') ?? 0.0;
        final double total = double.parse((precio * cant).toStringAsFixed(2));
        totalPaquete += total;

        final uri = Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/carrito');
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'id_encargado': userId,
            'id_producto': producto['id'],
            'cantidad': cant,
            'total': total,
          }),
        );

        if (res.statusCode >= 200 && res.statusCode < 300) {
          await _actualizarCantidadLocal(producto, cant);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error al agregar un producto del paquete (${res.statusCode})'),
              backgroundColor: Colors.red.shade400,
            ),
          );
          // Continuar con los demás ítems a pesar del error
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Paquete agregado: ${items.length} productos, total \$${totalPaquete.toStringAsFixed(2)}'),
          backgroundColor: gradientColors.last,
        ),
      );
      if (widget.pedidoMode) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VentasPedidosView()),
        );
      } else {
        Navigator.pushNamed(context, '/ventas');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creando paquete: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  void _mostrarMenuOpciones() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Opciones del Inventario',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.download, color: gradientColors.first),
                  title: Text(
                    'Descargar Inventario',
                    style: GoogleFonts.poppins(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _descargarInventario();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.email, color: gradientColors.last),
                  title: Text(
                    'Enviar por Correo',
                    style: GoogleFonts.poppins(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _enviarPorCorreo();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _descargarInventario() async {
    try {
      final List<Map<String, dynamic>> datosExportacion = [];

      for (var producto in _filteredSortedProductos()) {
        datosExportacion.add({
          'ID': producto['id'],
          'Producto': producto['nombre'],
          'Cantidad': producto['cantidad_asignada'] ?? 0,
          'Precio': producto['precio'],
          'Total': ((producto['cantidad_asignada'] ?? 0) *
                  (double.tryParse(producto['precio'].toString()) ?? 0.0))
              .toStringAsFixed(2),
        });
      }

      _generarCSV(datosExportacion);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inventario descargado', style: GoogleFonts.poppins()),
          backgroundColor: gradientColors.first,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _enviarPorCorreo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final decoded = JwtDecoder.decode(token);
      final email = decoded['email'] ?? 'usuario@example.com';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enviando inventario a $email...',
              style: GoogleFonts.poppins()),
          backgroundColor: gradientColors.last,
          duration: const Duration(seconds: 2),
        ),
      );

      // Simular envío (aquí irían las llamadas a la API real)
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Inventario enviado exitosamente!',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generarCSV(List<Map<String, dynamic>> datos) {
    final buffer = StringBuffer();
    if (datos.isEmpty) return buffer.toString();

    // Encabezados
    final headers = datos[0].keys.toList();
    buffer.writeln(headers.join(','));

    // Datos
    for (var fila in datos) {
      buffer.writeln(headers.map((h) => fila[h]).join(','));
    }

    return buffer.toString();
  }
}

class _ArmarPaquetePage extends StatefulWidget {
  final List productos;
  final List<Color> colors;
  const _ArmarPaquetePage({required this.productos, required this.colors});

  @override
  State<_ArmarPaquetePage> createState() => _ArmarPaquetePageState();
}

class _ArmarPaquetePageState extends State<_ArmarPaquetePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = '';
  final Map<int, int> _cantidades = {}; // id -> cantidad

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List _filtered() {
    if (_q.isEmpty) return widget.productos;
    final q = _q.toLowerCase();
    return widget.productos
        .where((p) => (p['nombre']?.toString().toLowerCase() ?? '').contains(q))
        .toList();
  }

  int _stockOf(Map p) {
    final c = p['cantidad_asignada'] ?? 0;
    return c is num ? c.toInt() : int.tryParse('$c') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final itemsSel = _cantidades.entries.where((e) => e.value > 0).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: widget.colors.first,
        elevation: 0,
        title: Text('Armar paquete',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: widget.colors.first)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar productos...',
                  prefixIcon: Icon(Icons.search, color: widget.colors.first),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _filtered().length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemBuilder: (context, i) {
                  final p = _filtered()[i] as Map;
                  final idRaw = p['id'];
                  final int id = (idRaw is int)
                      ? idRaw
                      : int.tryParse(idRaw?.toString() ?? '') ?? -1;
                  final stock = _stockOf(p);
                  final enabled = stock > 0;
                  final selCant = _cantidades[id] ?? 0;
                  return Opacity(
                    opacity: enabled ? 1.0 : 0.5,
                    child: Container(
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        leading: Checkbox(
                          value: selCant > 0,
                          onChanged: enabled
                              ? (v) {
                                  setState(() {
                                    _cantidades[id] = v == true ? 1 : 0;
                                  });
                                }
                              : null,
                        ),
                        title: Text(
                          (p['nombre'] ?? '').toString(),
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Stock: $stock',
                            style:
                                GoogleFonts.poppins(color: Colors.grey[700])),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: enabled && selCant > 0
                                  ? () => setState(() => _cantidades[id] =
                                      (selCant - 1).clamp(0, stock))
                                  : null,
                            ),
                            Text('$selCant'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: enabled && selCant < stock
                                  ? () => setState(() => _cantidades[id] =
                                      (selCant + 1).clamp(0, stock))
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: widget.colors.first),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancelar',
                            style: GoogleFonts.poppins(
                                color: widget.colors.first,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: itemsSel == 0
                            ? null
                            : () {
                                final sel = <_PaqueteItem>[];
                                for (final entry in _cantidades.entries) {
                                  if (entry.value > 0) {
                                    final prod = widget.productos.firstWhere(
                                      (p) {
                                        final r = p['id'];
                                        final int pid = (r is int)
                                            ? r
                                            : int.tryParse(
                                                    r?.toString() ?? '') ??
                                                -1;
                                        return pid == entry.key;
                                      },
                                      orElse: () => null,
                                    );
                                    if (prod != null) {
                                      sel.add(_PaqueteItem(
                                          producto: prod as Map,
                                          cantidad: entry.value));
                                    }
                                  }
                                }
                                Navigator.pop(context, sel);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: widget.colors),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('Agregar (${itemsSel})',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

enum _SortMode { priceAsc, alpha, favorites }

// Stylish product tile similar to gradient buttons in LoginView, with its own animations
class _ProductTile extends StatefulWidget {
  final String nombre;
  final String imagenUrl;
  final int cantidad;
  final String? precio;
  final String? precioUnitario;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final bool lowStock;
  final bool outOfStock;

  const _ProductTile({
    Key? key,
    required this.nombre,
    required this.imagenUrl,
    required this.cantidad,
    this.precio,
    this.precioUnitario,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.gradientColors,
    this.onTap,
    this.lowStock = false,
    this.outOfStock = false,
  }) : super(key: key);

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.outOfStock ? null : (_) => setState(() => _pressed = true),
      onTapUp:
          widget.outOfStock ? null : (_) => setState(() => _pressed = false),
      onTapCancel:
          widget.outOfStock ? null : () => setState(() => _pressed = false),
      onTap: widget.outOfStock ? null : widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: widget.outOfStock ? 0.6 : 1.0,
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
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image area
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
                              // subtle bottom gradient for readability
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
                      // Info area
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
                                    colors: widget.outOfStock
                                        ? [
                                            Colors.grey.shade400,
                                            Colors.grey.shade500
                                          ]
                                        : widget.lowStock
                                            ? [
                                                Colors.orange.shade400,
                                                Colors.orange.shade600
                                              ]
                                            : widget.gradientColors,
                                  ),
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
                                    Icon(
                                      widget.outOfStock
                                          ? Icons.block
                                          : widget.lowStock
                                              ? Icons.warning_amber_rounded
                                              : Icons.inventory_2,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.outOfStock
                                          ? 'Sin stock'
                                          : widget.lowStock
                                              ? '${widget.cantidad} (Bajo)'
                                              : '${widget.cantidad} unidades',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (widget.precio != null) ...[
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
                                        color: Colors.purple, size: 16),
                                    Text(
                                      widget.precio!,
                                      style: const TextStyle(
                                        color: Colors.purple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Precio unitario oculto pero existe en el modelo
                            // if (widget.precioUnitario != null) ...[
                            //   const SizedBox(height: 4),
                            //   Container(
                            //     padding: const EdgeInsets.symmetric(
                            //         horizontal: 10, vertical: 4),
                            //     decoration: BoxDecoration(
                            //       color: Colors.pink.shade50,
                            //       borderRadius: BorderRadius.circular(8),
                            //     ),
                            //     child: Row(
                            //       mainAxisSize: MainAxisSize.min,
                            //       mainAxisAlignment: MainAxisAlignment.center,
                            //       children: [
                            //         const Icon(Icons.monetization_on,
                            //             color: Color(0xFFF26AB6), size: 14),
                            //         const SizedBox(width: 4),
                            //         Text(
                            //           'Unit: ${widget.precioUnitario}',
                            //           style: const TextStyle(
                            //             color: Color(0xFFF26AB6),
                            //             fontWeight: FontWeight.w600,
                            //             fontSize: 12,
                            //           ),
                            //         ),
                            //       ],
                            //     ),
                            //   ),
                            // ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Favorite star
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _FavoriteStar(
                      active: widget.isFavorite,
                      onTap: widget.onToggleFavorite,
                      colors: widget.gradientColors,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CantidadDialog extends StatefulWidget {
  final int max;
  final List<Color> colors;
  const _CantidadDialog({required this.max, required this.colors});

  @override
  State<_CantidadDialog> createState() => _CantidadDialogState();
}

class _CantidadDialogState extends State<_CantidadDialog> {
  int _cantidad = 1;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir cantidad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Text('Disponible: ${widget.max}')],
      ),
      actions: [
        IconButton(
          onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$_cantidad'),
        IconButton(
          onPressed:
              _cantidad < widget.max ? () => setState(() => _cantidad++) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop<int>(context, _cantidad),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.colors.first,
          ),
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// Nueva vista a pantalla completa para elegir cantidad, estética similar al Admin
class _CantidadPage extends StatefulWidget {
  final int max;
  final List<Color> colors;
  const _CantidadPage({required this.max, required this.colors});

  @override
  State<_CantidadPage> createState() => _CantidadPageState();
}

class _CantidadPageState extends State<_CantidadPage> {
  int _cantidad = 1;

  void _inc() {
    setState(() {
      if (_cantidad < widget.max) _cantidad++;
    });
  }

  void _dec() {
    setState(() {
      if (_cantidad > 1) _cantidad--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: widget.colors.first,
        title: Text('Elegir cantidad',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: widget.colors.first)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset('assets/images/Logo.png',
                    height: 90, fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Disponible: ${widget.max}',
                        style: GoogleFonts.poppins(color: Colors.grey[700])),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundIconButton(
                            icon: Icons.remove,
                            onTap: _dec,
                            enabled: _cantidad > 1,
                            colors: widget.colors),
                        const SizedBox(width: 22),
                        Text('$_cantidad',
                            style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: widget.colors.first)),
                        const SizedBox(width: 22),
                        _RoundIconButton(
                            icon: Icons.add,
                            onTap: _inc,
                            enabled: _cantidad < widget.max,
                            colors: widget.colors),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: widget.colors.first),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancelar',
                          style: GoogleFonts.poppins(
                              color: widget.colors.first,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop<int>(context, _cantidad),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: widget.colors),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('Agregar',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Botón redondo para +/- con sombras y colores de marca
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final List<Color> colors;
  const _RoundIconButton(
      {required this.icon,
      required this.onTap,
      required this.enabled,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(icon, color: colors.first, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteStar extends StatefulWidget {
  final bool active;
  final VoidCallback onTap;
  final List<Color> colors;
  const _FavoriteStar(
      {Key? key,
      required this.active,
      required this.onTap,
      required this.colors})
      : super(key: key);

  @override
  State<_FavoriteStar> createState() => _FavoriteStarState();
}

class _FavoriteStarState extends State<_FavoriteStar>
    with SingleTickerProviderStateMixin {
  late bool _active;
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _active = widget.active;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    if (_active) {
      _ctrl.forward();
    } else {
      // Ensura que la estrella no desaparezca en estado inactivo
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _FavoriteStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != _active) {
      _active = widget.active;
      if (_active) {
        _ctrl.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
            ],
          ),
          child: ScaleTransition(
            scale: _scale,
            child: Icon(
              widget.active ? Icons.star : Icons.star_border,
              color: widget.active ? widget.colors.first : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }
}
