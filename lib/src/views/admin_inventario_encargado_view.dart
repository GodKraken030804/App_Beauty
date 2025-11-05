import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:file_saver/file_saver.dart';
import 'package:excel/excel.dart' as ex;
import 'package:app_beauty/src/views/admin_view.dart';
import 'package:app_beauty/src/views/mi_perfil_admin.dart';

class AdminInventarioEncargadoView extends StatefulWidget {
  final int encargadoId;
  final String nombre;
  const AdminInventarioEncargadoView(
      {super.key, required this.encargadoId, required this.nombre});

  @override
  State<AdminInventarioEncargadoView> createState() =>
      _AdminInventarioEncargadoViewState();
}

class _AdminInventarioEncargadoViewState
    extends State<AdminInventarioEncargadoView> {
  final List<Color> gradientColors = const [
    Color(0xFFF26AB6),
    Color(0xFFAA57EC)
  ];
  List<Map<String, dynamic>> _productos = [];
  String _query = '';
  Timer? _timer;
  // Favoritos + sort
  final String _favKeyPrefix = 'admin_inv_favs_';
  Set<int> _favoriteIds = <int>{};
  _SortMode _sortMode = _SortMode.alpha;

  @override
  void initState() {
    super.initState();
    _fetchInventario();
    // Actualización periódica para datos "en tiempo real"
    _timer =
        Timer.periodic(const Duration(seconds: 12), (_) => _fetchInventario());
    _loadFavorites();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchInventario() async {
    try {
      final asignadoUri =
          Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/asignado');
      final productoUri =
          Uri.parse('${dotenv.env['API_EMPRESA']}api/v1/producto');

      final asignadoRes = await http.get(asignadoUri);
      final productoRes = await http.get(productoUri);

      if (asignadoRes.statusCode == 200 && productoRes.statusCode == 200) {
        final asignaciones = jsonDecode(asignadoRes.body) as List;
        final productosAll = jsonDecode(productoRes.body) as List;

        // Filtra asignaciones del encargado
        final asignados = asignaciones.where((a) {
          final aidRaw = a['iduser'];
          final int aid = aidRaw is int
              ? aidRaw
              : int.tryParse(aidRaw?.toString() ?? '') ?? -1;
          return aid == widget.encargadoId;
        }).toList();

        // Agrupa por id de producto y suma cantidades
        final Map<int, Map<String, dynamic>> agrupados = {};
        for (final a in asignados) {
          final pidRaw = a['idproduc'];
          final int pid = pidRaw is int
              ? pidRaw
              : int.tryParse(pidRaw?.toString() ?? '') ?? -1;
          if (pid == -1) continue;
          final producto = productosAll.firstWhere(
            (p) {
              final idRaw = p['id'];
              final int id = idRaw is int
                  ? idRaw
                  : int.tryParse(idRaw?.toString() ?? '') ?? -1;
              return id == pid;
            },
            orElse: () => null,
          );
          if (producto == null) continue;
          final nombre = (producto['nombre'] ?? '').toString();
          final imagen = (producto['imagen'] ?? '').toString();
          final precioRaw = producto['precio'];
          final double precio = precioRaw is num
              ? precioRaw.toDouble()
              : double.tryParse('${precioRaw}') ?? 0.0;
          final cantRaw = a['cantidad'];
          final int cant = cantRaw is num
              ? cantRaw.toInt()
              : int.tryParse(cantRaw?.toString() ?? '') ?? 0;

          if (!agrupados.containsKey(pid)) {
            agrupados[pid] = {
              'id': pid,
              'nombre': nombre,
              'imagen': imagen,
              'precio': precio,
              'cantidad_asignada': cant,
            };
          } else {
            agrupados[pid]!['cantidad_asignada'] =
                (agrupados[pid]!['cantidad_asignada'] as int) + cant;
          }
        }

        setState(() {
          _productos = agrupados.values.toList();
        });
      }
    } catch (e) {
      // Silenciar errores para mantener UI
    }
  }

  // ===================== Favorites =====================
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_favKeyPrefix${widget.encargadoId}';
    final list = prefs.getStringList(key) ?? <String>[];
    setState(() {
      _favoriteIds =
          list.map((e) => int.tryParse(e) ?? -1).where((e) => e != -1).toSet();
    });
  }

  Future<void> _toggleFavorite(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_favKeyPrefix${widget.encargadoId}';
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
    await prefs.setStringList(
        key, _favoriteIds.map((e) => e.toString()).toList());
  }

  // ===================== Sort/Filter =====================
  List<Map<String, dynamic>> _filteredSortedProductos() {
    List<Map<String, dynamic>> list = _productos;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
              (p) => (p['nombre'] ?? '').toString().toLowerCase().contains(q))
          .toList();
    }
    if (_sortMode == _SortMode.favorites) {
      list = list.where((p) {
        final idRaw = p['id'];
        final int id = idRaw is int ? idRaw : int.tryParse('${idRaw}') ?? -1;
        return _favoriteIds.contains(id);
      }).toList();
      list.sort((a, b) => (a['nombre'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['nombre'] ?? '').toString().toLowerCase()));
    } else if (_sortMode == _SortMode.priceAsc) {
      list.sort((a, b) {
        final double pa = (a['precio'] is num)
            ? (a['precio'] as num).toDouble()
            : double.tryParse('${a['precio']}') ?? 0.0;
        final double pb = (b['precio'] is num)
            ? (b['precio'] as num).toDouble()
            : double.tryParse('${b['precio']}') ?? 0.0;
        return pa.compareTo(pb);
      });
    } else {
      list.sort((a, b) => (a['nombre'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['nombre'] ?? '').toString().toLowerCase()));
    }
    return list;
  }

  // Nota: la lógica de filtrado ya está integrada en _filteredSortedProductos()

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      floatingActionButton: _buildExportFab(),
      body: Column(
        children: [
          // Barra superior con degradado
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
          // Encabezado con logo y título
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Center(
                  child: Image.asset('assets/images/Logo.png',
                      height: 90, fit: BoxFit.contain),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inventario de ${widget.nombre}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: gradientColors.first,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Buscador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFFF26AB6)),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                ),
                style: GoogleFonts.poppins(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Controles de orden
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _segButton('A-Z', Icons.sort_by_alpha, _SortMode.alpha,
                      radius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      )),
                  _segDivider(),
                  _segButton('Precio', Icons.attach_money, _SortMode.priceAsc),
                  _segDivider(),
                  _segButton('Favoritos', Icons.star, _SortMode.favorites,
                      radius: const BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchInventario,
              child: _filteredSortedProductos().isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text('Sin productos asignados',
                              style: GoogleFonts.poppins(color: Colors.grey)),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _filteredSortedProductos().length,
                      itemBuilder: (context, index) {
                        final p = _filteredSortedProductos()[index];
                        final idRaw = p['id'];
                        final int id = idRaw is int
                            ? idRaw
                            : int.tryParse('${idRaw}') ?? -1;
                        final cantidad = (p['cantidad_asignada'] ?? 0) as int;
                        return _ProductoTile(
                          nombre: (p['nombre'] ?? '').toString(),
                          imagen: (p['imagen'] ?? '').toString(),
                          cantidad: cantidad,
                          precio: (p['precio'] is num)
                              ? (p['precio'] as num).toDouble()
                              : double.tryParse('${p['precio']}') ?? 0.0,
                          isFavorite: _favoriteIds.contains(id),
                          onToggleFavorite: () => _toggleFavorite(id),
                          colors: gradientColors,
                          lowStock: cantidad > 0 && cantidad < 5,
                          outOfStock: cantidad == 0,
                        );
                      },
                    ),
            ),
          ),
        ],
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
              onTap: (index) {
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
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Principal',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Mi Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ====== Exportación a Excel ======
  Widget _buildExportFab() {
    return _buildGradientSquareButton(
      icon: Icons.file_download_outlined,
      onTap: _exportExcel,
      colors: gradientColors,
      tooltip: 'Exportar inventario',
    );
  }

  Future<void> _exportExcel() async {
    final now = DateTime.now();
    final ts = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    // Exporta lo que está actualmente filtrado y ordenado, para reflejar "lo que ves".
    final data = _filteredSortedProductos();
    if (data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay productos para exportar')),
        );
      }
      return;
    }

    final excel = ex.Excel.createExcel();
    final sheet = excel['Inventario'];
    sheet.appendRow(['Inventario de', widget.nombre]);
    sheet.appendRow(['Exportado', now.toLocal().toString().split('.').first]);
    sheet.appendRow([]);
    sheet.appendRow(['Producto', 'Cantidad', 'Precio', 'Total']);

    for (final p in data) {
      final nombre = (p['nombre'] ?? '').toString();
      final cant = (p['cantidad_asignada'] ?? 0) as int;
      final precio = (p['precio'] is num)
          ? (p['precio'] as num).toDouble()
          : double.tryParse('${p['precio']}') ?? 0.0;
      final total = precio * cant;
      sheet.appendRow([nombre, cant, precio, total]);
    }

    final bytesList = excel.encode();
    if (bytesList == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el archivo Excel')),
        );
      }
      return;
    }
    final bytes = Uint8List.fromList(bytesList);

    final safeNombre = widget.nombre.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final filename = 'Inventario_${safeNombre}_$ts.xlsx';

    if (kIsWeb) {
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Descarga iniciada: $filename')),
        );
      }
      return;
    }

    try {
      final res = await FileSaver.instance.saveFile(
        name: filename.replaceAll('.xlsx', ''),
        ext: 'xlsx',
        bytes: bytes,
        mimeType: MimeType.other,
      );
      if (mounted) {
        final ok = res.toString().isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Archivo guardado: $filename'
                : 'No se pudo guardar el archivo'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  // Botón cuadrado con gradiente (coherente con el estilo)
  Widget _buildGradientSquareButton({
    required IconData icon,
    required VoidCallback onTap,
    required List<Color> colors,
    String? tooltip,
  }) {
    final borderRadius = BorderRadius.circular(15);
    final btn = Material(
      color: Colors.transparent,
      elevation: 5,
      shadowColor: Colors.grey.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: borderRadius,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: const SizedBox(
            width: 64,
            height: 64,
            child: Center(
                child: Icon(Icons.file_download_outlined,
                    color: Colors.white, size: 30)),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _segDivider() =>
      Container(width: 1, height: 44, color: Colors.grey.shade200);

  Widget _segButton(String text, IconData icon, _SortMode mode,
      {BorderRadius? radius}) {
    final selected = _sortMode == mode;
    return Expanded(
      child: InkWell(
        borderRadius: radius ?? BorderRadius.zero,
        onTap: () => setState(() => _sortMode = mode),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? gradientColors.first.withOpacity(0.10)
                : Colors.white,
            borderRadius: radius,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? gradientColors.first : Colors.grey[700]),
              const SizedBox(width: 6),
              Text(text,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: selected ? gradientColors.first : Colors.grey[800],
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SortMode { priceAsc, alpha, favorites }

class _ProductoTile extends StatelessWidget {
  final String nombre;
  final String imagen;
  final int cantidad;
  final double precio;
  final List<Color> colors;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final bool lowStock;
  final bool outOfStock;
  const _ProductoTile(
      {required this.nombre,
      required this.imagen,
      required this.cantidad,
      required this.precio,
      required this.colors,
      required this.isFavorite,
      required this.onToggleFavorite,
      this.lowStock = false,
      this.outOfStock = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 4))
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.inventory_2, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(nombre,
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colors.first)),
                      ),
                      InkWell(
                        onTap: onToggleFavorite,
                        borderRadius: BorderRadius.circular(20),
                        child: Icon(isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite ? colors.first : Colors.grey),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Cantidad: $cantidad',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.black87)),
                      const SizedBox(width: 10),
                      if (precio > 0)
                        Text('Precio: \$${precio.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (outOfStock)
                    _badge('Sin stock', Colors.red.shade50, Colors.red.shade400)
                  else if (lowStock)
                    _badge('Stock bajo', Colors.orange.shade50,
                        Colors.orange.shade600),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: fg.withOpacity(0.3))),
        child: Text(text,
            style: GoogleFonts.poppins(
                color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
