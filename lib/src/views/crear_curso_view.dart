import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class CrearCursoView extends StatefulWidget {
  const CrearCursoView({super.key});

  @override
  State<CrearCursoView> createState() => _CrearCursoViewState();
}

class _CrearCursoViewState extends State<CrearCursoView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController ciudadController = TextEditingController();
  DateTime? fechaInicio;
  DateTime? fechaFin;

  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  Future<void> _selectDate(BuildContext context, bool isInicio) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          fechaInicio = picked;
        } else {
          fechaFin = picked;
        }
      });
    }
  }

  Future<void> _crearCurso() async {
    if (_formKey.currentState!.validate() && fechaInicio != null && fechaFin != null) {
      final url = Uri.parse('${dotenv.env['API_EMPRESA']!.trim()}api/v1/curso');
      final body = {
        "id": 0,
        "nombre": nombreController.text.trim(),
        "ciudad": ciudadController.text.trim(),
        "fecha_inicial": fechaInicio!.toIso8601String(),
        "fecha_final": fechaFin!.toIso8601String(),
      };

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("¡Éxito!"),
              content: const Text("El curso se creó correctamente."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          nombreController.clear();
          ciudadController.clear();
          setState(() {
            fechaInicio = null;
            fechaFin = null;
          });
        } else {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Error"),
              content: Text("No se pudo crear el curso.\n${response.body}"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Error"),
            content: Text("Ocurrió un error: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // <-- Fondo blanco
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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/Logo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Creación De Curso",
                      style: TextStyle(
                        color: gradientStart,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: "Nombre De Curso",
                        labelStyle: TextStyle(color: Color(0xFFF26AB6)),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFF26AB6)),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Campo obligatorio" : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: ciudadController,
                      decoration: const InputDecoration(
                        labelText: "Ciudad",
                        labelStyle: TextStyle(color: Color(0xFFF26AB6)),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFF26AB6)),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Campo obligatorio" : null,
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _selectDate(context, true),
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: "Fecha De Inicio",
                            labelStyle: const TextStyle(color: Color(0xFFF26AB6)),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFF26AB6)),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFFF26AB6)),
                          ),
                          controller: TextEditingController(
                            text: fechaInicio == null
                                ? ""
                                : "${fechaInicio!.day}/${fechaInicio!.month}/${fechaInicio!.year}",
                          ),
                          validator: (v) =>
                              fechaInicio == null ? "Selecciona una fecha" : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _selectDate(context, false),
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: "Fecha De Fin",
                            labelStyle: const TextStyle(color: Color(0xFFF26AB6)),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFF26AB6)),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFFF26AB6)),
                          ),
                          controller: TextEditingController(
                            text: fechaFin == null
                                ? ""
                                : "${fechaFin!.day}/${fechaFin!.month}/${fechaFin!.year}",
                          ),
                          validator: (v) =>
                              fechaFin == null ? "Selecciona una fecha" : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _crearCurso,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                          backgroundColor: gradientStart,
                          foregroundColor: Colors.white,
                        ).copyWith(
                          backgroundColor: MaterialStateProperty.resolveWith(
                            (states) => null,
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [gradientStart, gradientEnd],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: const Text(
                              "Crear Curso",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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