import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:another_flushbar/flushbar.dart';
import 'dart:convert';
import '../models/alumna_model.dart';

class RegistrarAlumnasNuevasView extends StatefulWidget {
  final dynamic curso;

  const RegistrarAlumnasNuevasView({super.key, required this.curso});

  @override
  State<RegistrarAlumnasNuevasView> createState() =>
      _RegistrarAlumnasNuevasViewState();
}

class _RegistrarAlumnasNuevasViewState
    extends State<RegistrarAlumnasNuevasView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _servicioController = TextEditingController();
  final TextEditingController _anticipoController = TextEditingController();
  String _metodoPago = 'Efectivo';
  final TextEditingController _digitosController = TextEditingController();

  final Color _gradientStart = const Color(0xFFF26AB6);
  final Color _gradientEnd = const Color(0xFFAA57EC);

  final List<String> _metodosPago = ['Efectivo', 'Transferencia', 'Tarjeta'];

  IconData _iconForMetodo(String m) {
    switch (m) {
      case 'Efectivo':
        return Icons.payments_rounded;
      case 'Transferencia':
        return Icons.account_balance;
      case 'Tarjeta':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  Color _colorForMetodo(String m) {
    switch (m) {
      case 'Efectivo':
        return Colors.green;
      case 'Transferencia':
        return Colors.blueAccent;
      case 'Tarjeta':
        return Colors.deepPurple;
      default:
        return _gradientEnd;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top gradient bar (same as Asignacion)
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_gradientStart, _gradientEnd],
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
                      // Big logo above the title (same placement as Asignacion)
                      Image.asset(
                        'assets/images/Logo.png',
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.curso['nombre'] != null
                            ? 'Registrar Alumna'
                            : 'Registrar Nueva Alumna',
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
                          controller: _nombreController,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Nombre Completo',
                            labelStyle:
                                GoogleFonts.poppins(color: Colors.grey[600]),
                            prefixIcon: const Icon(Icons.person,
                                color: Color(0xFFF26AB6)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                  color: Color(0xFFF26AB6), width: 1.5),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? "Campo obligatorio"
                              : null,
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
                          controller: _servicioController,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Servicio',
                            labelStyle:
                                GoogleFonts.poppins(color: Colors.grey[600]),
                            prefixIcon:
                                const Icon(Icons.spa, color: Color(0xFFF26AB6)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                  color: Color(0xFFF26AB6), width: 1.5),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? "Campo obligatorio"
                              : null,
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
                          controller: _anticipoController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Total de pago',
                            labelStyle:
                                GoogleFonts.poppins(color: Colors.grey[600]),
                            prefixIcon: const Icon(Icons.attach_money,
                                color: Color(0xFFF26AB6)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                  color: Color(0xFFF26AB6), width: 1.5),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Campo obligatorio";
                            }
                            if (double.tryParse(v) == null) {
                              return "Ingrese un valor válido";
                            }
                            return null;
                          },
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
                        child: DropdownButtonFormField<String>(
                          value: _metodoPago,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Método de pago',
                            labelStyle:
                                GoogleFonts.poppins(color: Colors.grey[600]),
                            prefixIcon: const Icon(Icons.payment,
                                color: Color(0xFFF26AB6)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                  color: Color(0xFFF26AB6), width: 1.5),
                            ),
                          ),
                          isExpanded: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _gradientStart,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          dropdownColor: Colors.white,
                          menuMaxHeight: 280,
                          items: _metodosPago
                              .map((method) => DropdownMenuItem<String>(
                                    value: method,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _iconForMetodo(method),
                                          color: _colorForMetodo(method),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          method,
                                          style: GoogleFonts.poppins(),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _metodoPago = value!;
                            });
                          },
                          validator: (v) =>
                              v == null ? "Seleccione un método" : null,
                        ),
                      ),
                      if (_metodoPago == 'Transferencia' ||
                          _metodoPago == 'Tarjeta')
                        const SizedBox(height: 20),
                      if (_metodoPago == 'Transferencia' ||
                          _metodoPago == 'Tarjeta')
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
                            controller: _digitosController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              labelText: 'Últimos 4 dígitos',
                              labelStyle:
                                  GoogleFonts.poppins(color: Colors.grey[600]),
                              prefixIcon: const Icon(Icons.numbers,
                                  color: Color(0xFFF26AB6)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                    color: Color(0xFFF26AB6), width: 1.5),
                              ),
                            ),
                            validator: (v) {
                              if ((_metodoPago == 'Transferencia' ||
                                      _metodoPago == 'Tarjeta') &&
                                  (v == null || v.isEmpty)) {
                                return "Campo obligatorio";
                              }
                              if (v != null &&
                                  v.isNotEmpty &&
                                  (v.length != 4 || int.tryParse(v) == null)) {
                                return "Ingrese 4 dígitos válidos";
                              }
                              return null;
                            },
                          ),
                        ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _registrarAlumna,
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
                                colors: [_gradientStart, _gradientEnd],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              constraints: const BoxConstraints(minHeight: 50),
                              child: Text(
                                'Registrar Alumna',
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
            colors: [_gradientStart, _gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                Navigator.pop(context);
              } else if (index == 1) {
                // Aquí puedes navegar al perfil si es necesario
              }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.arrow_back),
                label: "Regresar",
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

  Future<void> _registrarAlumna() async {
    if (_formKey.currentState!.validate()) {
      try {
        final nuevaAlumna = Alumna(
          nombre: _nombreController.text.trim(),
          servicio: _servicioController.text.trim(),
          anticipo: double.parse(_anticipoController.text),
          metodoPago: _metodoPago,
          digitos: _digitosController.text,
          llego: true, // Se marca automáticamente como que llegó
        );

        // Guardar en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final key = 'alumnas_curso_${widget.curso['id']}';
        final data = prefs.getString(key);
        List<dynamic> alumnas = [];

        if (data != null) {
          alumnas = jsonDecode(data) as List;
        }

        alumnas.add(nuevaAlumna.toJson());
        await prefs.setString(key, jsonEncode(alumnas));

        // Mostrar notificación de éxito
        Flushbar(
          margin: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(15),
          backgroundColor: _gradientStart,
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
            "Alumna registrada correctamente.",
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
          ),
          duration: const Duration(seconds: 3),
          animationDuration: const Duration(milliseconds: 500),
        ).show(context);

        // Limpiar formulario
        _nombreController.clear();
        _servicioController.clear();
        _anticipoController.clear();
        _digitosController.clear();
        setState(() {
          _metodoPago = 'Efectivo';
        });
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
            "Ocurrió un error al registrar: $e",
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
          ),
          duration: const Duration(seconds: 3),
          animationDuration: const Duration(milliseconds: 500),
        ).show(context);
      }
    }
  }
}
