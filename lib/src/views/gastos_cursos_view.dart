import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:google_fonts/google_fonts.dart';
import './gastos_view.dart'; // Import the per-course GastosView
import 'package:app_beauty/src/views/mi_perfil_view.dart'; // For navigation

class GastosCursosView extends StatefulWidget {
  const GastosCursosView({super.key});

  @override
  State<GastosCursosView> createState() => _GastosCursosViewState();
}

class _GastosCursosViewState extends State<GastosCursosView>
    with SingleTickerProviderStateMixin {
  List<dynamic> cursosAsignados = [];
  bool isLoading = true;
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _fetchCursosAsignados();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedButton(
      {required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: child,
      ),
    );
  }

  void _showGradientNotification(String title, String message,
      {bool isError = false}) {
    final colors = isError
        ? [Colors.red.shade400, Colors.red.shade600]
        : [gradientStart, gradientEnd];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 50,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Aceptar',
                    style: GoogleFonts.poppins(
                      color: gradientStart,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int?> _getUserIdFromToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);
        return decodedToken['id'] as int?;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> _fetchCursosAsignados() async {
    setState(() {
      isLoading = true;
    });

    try {
      final userId = await _getUserIdFromToken();

      if (userId == null) {
        _showGradientNotification("Error", "No se pudo identificar al usuario",
            isError: true);
        return;
      }

      final asignacionesUrl =
          Uri.parse('${dotenv.env['API_EMPRESA']!.trim()}api/v1/asignar-curso');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final asignacionesResponse = await http.get(
        asignacionesUrl,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (asignacionesResponse.statusCode == 200) {
        final asignaciones = jsonDecode(asignacionesResponse.body) as List;

        final asignacionesUsuario = asignaciones
            .where((asignacion) => asignacion['id_encargado'] == userId)
            .toList();

        final cursosUrl =
            Uri.parse('${dotenv.env['API_EMPRESA']!.trim()}api/v1/curso');
        final cursosResponse = await http.get(cursosUrl);

        if (cursosResponse.statusCode == 200) {
          final todosLosCursos = jsonDecode(cursosResponse.body) as List;

          final cursosDelUsuario = todosLosCursos.where((curso) {
            return asignacionesUsuario
                .any((asignacion) => asignacion['id_curso'] == curso['id']);
          }).toList();

          setState(() {
            cursosAsignados = cursosDelUsuario;
            isLoading = false;
          });
        } else {
          _showGradientNotification("Error", "Error al obtener los cursos",
              isError: true);
        }
      } else {
        _showGradientNotification("Error", "Error al obtener las asignaciones",
            isError: true);
      }
    } catch (e) {
      _showGradientNotification("Error", "Error de conexión", isError: true);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatearFecha(String fecha) {
    final date = DateTime.tryParse(fecha);
    if (date == null) return fecha;

    final meses = [
      "Enero",
      "Febrero",
      "Marzo",
      "Abril",
      "Mayo",
      "Junio",
      "Julio",
      "Agosto",
      "Septiembre",
      "Octubre",
      "Noviembre",
      "Diciembre"
    ];

    return "${date.day} De ${meses[date.month - 1]}";
  }

  Widget _buildFloatingActionButton() {
    final borderRadius = BorderRadius.circular(15);
    return Material(
      color: Colors.transparent,
      elevation: 5,
      shadowColor: Colors.grey.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: borderRadius,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () {
            _fetchCursosAsignados();
            _showGradientNotification(
                "Actualizado", "Lista de cursos actualizada");
          },
          child: const SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: Icon(Icons.refresh, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _buildFloatingActionButton(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildAnimatedButton(
                    onTap: () {},
                    child: Image.asset(
                      'assets/images/Logo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Mis Cursos para Gastos",
                    style: TextStyle(
                      color: gradientStart,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFF26AB6)),
                      ),
                    )
                  else if (cursosAsignados.isEmpty)
                    _buildAnimatedButton(
                      onTap: () {},
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.school, size: 60, color: Colors.grey),
                            SizedBox(height: 10),
                            Text(
                              "No tienes cursos asignados.",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...cursosAsignados.asMap().entries.map((entry) {
                      final curso = entry.value;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GastosView(curso: curso),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 18),
                            elevation: 5,
                            shadowColor: Colors.grey.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [gradientStart, gradientEnd],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Container(
                              padding: EdgeInsets.zero,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.school,
                                      color: Colors.white, size: 48),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          curso['nombre'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 19,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_city,
                                                size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                curso['ciudad'] ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today,
                                                size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                "Inicio: ${_formatearFecha(curso['fecha_inicial'] ?? '')}",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.event_available,
                                                size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                "Fin: ${_formatearFecha(curso['fecha_final'] ?? '')}",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios,
                                      color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          onTap: (index) {
            if (index == 0) {
              Navigator.pop(context);
            } else if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MiPerfilView()),
              );
            }
          },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: "Principal",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: "Mi Perfil",
              ),
            ],
        ),
      ),
    );
  }
}
