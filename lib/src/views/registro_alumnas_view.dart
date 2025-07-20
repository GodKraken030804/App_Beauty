import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import '../models/alumna_model.dart';
import 'options_view.dart';
import 'acceso_alumnas_view.dart';

class RegistroAlumnasView extends StatefulWidget {
  const RegistroAlumnasView({super.key});

  @override
  State<RegistroAlumnasView> createState() => _RegistroAlumnasViewState();
}

class _RegistroAlumnasViewState extends State<RegistroAlumnasView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController servicioController = TextEditingController();
  final TextEditingController anticipoController = TextEditingController();
  final TextEditingController metodoPagoController = TextEditingController();
  final TextEditingController digitosController = TextEditingController();

  List<Alumna> alumnas = [];

  @override
  void initState() {
    super.initState();
    _cargarAlumnasGuardadas();
  }

  Future<void> _cargarAlumnasGuardadas() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('alumnas_guardadas');
    if (data != null) {
      final jsonList = jsonDecode(data) as List;
      setState(() {
        alumnas = jsonList.map((e) => Alumna.fromJson(e)).toList();
      });
    }
  }

  Future<void> _guardarAlumnas() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = alumnas.map((a) => a.toJson()).toList();
    prefs.setString('alumnas_guardadas', jsonEncode(jsonList));
  }

  void _registrarAlumna() async {
    if (!_formKey.currentState!.validate()) return;

    final nombre = nombreController.text.trim();
    final servicio = servicioController.text.trim();
    final anticipo = double.tryParse(anticipoController.text.trim()) ?? 0;
    final metodoPago = metodoPagoController.text.trim();
    final digitos = digitosController.text.trim();

    final alumna = Alumna(
      nombre: nombre,
      servicio: servicio,
      anticipo: anticipo,
      metodoPago: metodoPago,
      digitos: digitos,
    );

    setState(() => alumnas.add(alumna));
    await _guardarAlumnas();

    Flushbar(
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(15),
      backgroundColor: const Color(0xFFF26AB6),
      flushbarPosition: FlushbarPosition.TOP,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
      titleText: const Text("¡Registrado!", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
      messageText: const Text("Alumna registrada correctamente", style: TextStyle(fontSize: 16, color: Colors.white)),
      duration: const Duration(seconds: 3),
    ).show(context);

    nombreController.clear();
    servicioController.clear();
    anticipoController.clear();
    metodoPagoController.clear();
    digitosController.clear();

    // Navega a AccesoAlumnasView y pasa la lista actualizada
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AccesoAlumnasView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = const Color(0xFFF26AB6);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 30),
          SizedBox(height: 120, child: Image.asset('assets/images/Logo.png')),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: servicioController,
                    decoration: const InputDecoration(labelText: 'Servicio'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: anticipoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Anticipo'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: metodoPagoController,
                    decoration: const InputDecoration(labelText: 'Método de pago'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: digitosController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(labelText: '4 Dígitos (si aplica)'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _registrarAlumna,
                    icon: const Icon(Icons.check),
                    label: const Text('Registrar Alumna'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: SizedBox(
              height: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: () => Navigator.pushReplacement(
                        context, MaterialPageRoute(builder: (_) => const OptionsView())),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home, color: Colors.white, size: 40),
                        Text('Principal', style: TextStyle(color: Colors.white))
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pushReplacement(
                        context, MaterialPageRoute(builder: (_) => const AccesoAlumnasView())),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, color: Colors.white, size: 40),
                        Text('Alumnas', style: TextStyle(color: Colors.white))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
