import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:app_beauty/src/views/admin_view.dart';
import 'package:app_beauty/src/views/mi_perfil_admin.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:another_flushbar/flushbar.dart';

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

  // Selección de fechas
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

  // Creación de curso
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
          Flushbar(
            margin: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(15),
            backgroundColor: gradientStart,
            flushbarPosition: FlushbarPosition.TOP,
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
            titleText: Text(
              "¡Éxito!",
              style: GoogleFonts.poppins(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            messageText: Text(
              "El curso se creó correctamente.",
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
            ),
            duration: const Duration(seconds: 3),
            animationDuration: const Duration(milliseconds: 500),
          ).show(context);
          nombreController.clear();
          ciudadController.clear();
          setState(() {
            fechaInicio = null;
            fechaFin = null;
          });
        } else {
          Flushbar(
            margin: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(15),
            backgroundColor: Colors.redAccent,
            flushbarPosition: FlushbarPosition.TOP,
            icon: const Icon(Icons.error, color: Colors.white, size: 28),
            titleText: Text(
              "Error",
              style: GoogleFonts.poppins(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            messageText: Text(
              "No se pudo crear el curso.\n${response.body}",
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
            ),
            duration: const Duration(seconds: 3),
            animationDuration: const Duration(milliseconds: 500),
          ).show(context);
        }
      } catch (e) {
        Flushbar(
          margin: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(15),
          backgroundColor: Colors.redAccent,
          flushbarPosition: FlushbarPosition.TOP,
          icon: const Icon(Icons.error, color: Colors.white, size: 28),
          titleText: Text(
            "Error",
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          messageText: Text(
            "Ocurrió un error: $e",
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
          ),
          duration: const Duration(seconds: 3),
          animationDuration: const Duration(milliseconds: 500),
        ).show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Top gradient bar for visual consistency
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 160,
                        child: Image.asset(
                          'assets/images/Logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Creación De Curso",
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
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
                        child: TextFormField(
                          controller: nombreController,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Nombre De Curso',
                            labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                            prefixIcon: const Icon(Icons.create, color: Color(0xFFF26AB6)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Color(0xFFF26AB6), width: 1.5),
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? "Campo obligatorio" : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
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
                        child: TextFormField(
                          controller: ciudadController,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Ciudad',
                            labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                            prefixIcon: const Icon(Icons.location_city, color: Color(0xFFF26AB6)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Color(0xFFF26AB6), width: 1.5),
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? "Campo obligatorio" : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
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
                        child: GestureDetector(
                          onTap: () => _selectDate(context, true),
                          child: AbsorbPointer(
                            child: TextFormField(
                              style: GoogleFonts.poppins(),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                labelText: 'Fecha De Inicio',
                                labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                                prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFFF26AB6)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Color(0xFFF26AB6), width: 1.5),
                                ),
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
                      ),
                      const SizedBox(height: 20),
                      Container(
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
                        child: GestureDetector(
                          onTap: () => _selectDate(context, false),
                          child: AbsorbPointer(
                            child: TextFormField(
                              style: GoogleFonts.poppins(),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                labelText: 'Fecha De Fin',
                                labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                                prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFFF26AB6)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Color(0xFFF26AB6), width: 1.5),
                                ),
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
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _crearCurso,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            shadowColor: Colors.grey.withOpacity(0.5),
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
                              alignment: Alignment.center,
                              constraints: const BoxConstraints(minHeight: 50),
                              child: Text(
                                'Crear Curso',
                                style: GoogleFonts.poppins(
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
            ],
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
                label: "Principal",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: "Mi Perfil",
              ),
            ],
          ),
        ),
      ),
    );
  }
}