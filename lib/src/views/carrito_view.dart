import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CarritoView extends StatefulWidget {
  const CarritoView({super.key});

  @override
  State<CarritoView> createState() => _CarritoViewState();
}

class _CarritoViewState extends State<CarritoView> {
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  bool _loading = true;
  String? _error;
  List<dynamic> _items = const [];

  @override
  void initState() {
    super.initState();
    _fetchCarrito();
  }

  Future<void> _fetchCarrito() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = Uri.parse('${dotenv.env['API_GATEWAY']}api/v1/carrito');
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        setState(() {
          _items = (data is List) ? data : [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${res.statusCode} al cargar carrito';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de red: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientStart, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: GoogleFonts.poppins()),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchCarrito,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ))
              : _items.isEmpty
                  ? Center(
                      child: Text('Tu carrito está vacío',
                          style:
                              GoogleFonts.poppins(color: Colors.grey.shade700)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final it = _items[i] as Map<String, dynamic>;
                        final idProd = it['id_producto'] ??
                            it['idproduc'] ??
                            it['producto_id'] ??
                            '-';
                        final cant = it['cantidad'] ?? it['qty'] ?? 0;
                        final total = (it['total'] is num)
                            ? (it['total'] as num).toDouble()
                            : double.tryParse('${it['total']}') ?? 0.0;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              )
                            ],
                          ),
                          child: ListTile(
                            title: Text('Producto $idProd',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('Cantidad: $cant',
                                style: GoogleFonts.poppins()),
                            trailing: Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: gradientEnd),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
