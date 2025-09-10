import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_beauty/src/views/options_view.dart';
import 'package:app_beauty/src/views/mi_perfil_view.dart';
import 'package:google_fonts/google_fonts.dart';
// Removed exports & menu dependencies as per new requirements

class ProductosExcelView extends StatefulWidget {
  const ProductosExcelView({super.key});

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
    final imagenUrl = "${dotenv.env['API_GATEWAY']}imagenes/$imagenNombre";
    final cantidad = producto['cantidad_asignada'] ?? 0;
    final nombre = producto['nombre'] ?? '';
    final idRaw = producto['id'];
    final int id =
        (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? -1;
    final isFav = _favoriteIds.contains(id);

    return _ProductTile(
      nombre: nombre.toString(),
      imagenUrl: imagenUrl,
      cantidad: cantidad is num
          ? cantidad.toInt()
          : int.tryParse(cantidad.toString()) ?? 0,
      isFavorite: isFav,
      onToggleFavorite: () => _toggleFavorite(id),
      gradientColors: gradientColors,
      onTap: () => _onTapProducto(producto),
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Producto agregado a ventas'),
            backgroundColor: gradientColors.last,
          ),
        );
        Navigator.pushNamed(context, '/ventas');
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
                Text(
                  'Inventario',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: gradientColors.first,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
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
      // Removed floatingActionButton (hamburger menu) per request
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

enum _SortMode { priceAsc, alpha, favorites }

// Stylish product tile similar to gradient buttons in LoginView, with its own animations
class _ProductTile extends StatefulWidget {
  final String nombre;
  final String imagenUrl;
  final int cantidad;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  const _ProductTile({
    Key? key,
    required this.nombre,
    required this.imagenUrl,
    required this.cantidad,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.gradientColors,
    this.onTap,
  }) : super(key: key);

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
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
