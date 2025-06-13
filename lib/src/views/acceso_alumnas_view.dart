import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:another_flushbar/flushbar.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
import '../models/alumna_model.dart';
import 'options_view.dart'; // <- Para navegar a Principal

class AccesoAlumnasView extends StatefulWidget {
  const AccesoAlumnasView({super.key});

  @override
  State<AccesoAlumnasView> createState() => _AccesoAlumnasViewState();
}

class _AccesoAlumnasViewState extends State<AccesoAlumnasView> {
  List<Alumna> alumnas = [];
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

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

  Future<void> _guardarAlumnas(List<Alumna> lista) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = lista.map((a) => a.toJson()).toList();
    prefs.setString('alumnas_guardadas', jsonEncode(jsonList));
  }

  void _mostrarNotificacion(String titulo, String mensaje) {
    Flushbar(
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(15),
      backgroundColor: gradientStart,
      flushbarPosition: FlushbarPosition.TOP,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
      titleText: Text(
        titulo,
        style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      messageText: Text(
        mensaje,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 500),
    ).show(context);
  }

  Future<void> _importarExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result != null) {
      Uint8List? bytes;

      if (kIsWeb) {
        bytes = result.files.first.bytes;
      } else {
        final path = result.files.first.path;
        if (path != null) {
          bytes = await io.File(path).readAsBytes();
        }
      }

      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo seleccionado')),
        );
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      final Sheet? hoja = excel.tables[excel.tables.keys.first];

      if (hoja != null) {
        List<Alumna> cargadas = [];

        for (int i = 1; i < hoja.maxRows; i++) {
          final fila = hoja.row(i);
          final nombre = fila[0]?.value.toString() ?? '';
          final servicio = fila[1]?.value.toString() ?? '';
          final anticipo = double.tryParse(fila[2]?.value.toString() ?? '0') ?? 0;

          cargadas.add(Alumna(
            nombre: nombre,
            servicio: servicio,
            anticipo: anticipo,
          ));
        }

        setState(() {
          alumnas = cargadas;
        });

        await _guardarAlumnas(cargadas);

        _mostrarNotificacion("Excel cargado", "Se han importado correctamente los datos.");
      }
    }
  }

  Future<void> _exportarExcel() async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Alumnas'];
    sheet.appendRow(['Nombre', 'Servicio', 'Anticipo']);
    for (var alumna in alumnas) {
      sheet.appendRow([alumna.nombre, alumna.servicio, alumna.anticipo]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final directory = await FilePicker.platform.getDirectoryPath();
    if (directory != null) {
      final String path = "$directory/alumnas_exportadas.xlsx";
      final file = io.File(path);
      await file.writeAsBytes(bytes, flush: true);
      _mostrarNotificacion("Exportación completa", "El archivo se guardó correctamente en $path");
    }
  }

  void _mostrarDialogoLlegada(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('¿${alumnas[index].nombre} llegó?'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  alumnas[index].llego = false;
                });
                _guardarAlumnas(alumnas);
                Navigator.pop(context);
              },
              child: const Text('No llegó'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  alumnas[index].llego = true;
                });
                _guardarAlumnas(alumnas);
                Navigator.pop(context);
              },
              child: const Text('Sí llegó'),
            ),
          ],
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
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: SizedBox(
              height: 100,
              child: Image.asset(
                'assets/images/Logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Botón Subir Excel
                GestureDetector(
                  onTap: _importarExcel,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: Text(
                        "Subir Excel",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Lista de alumnas
                ...alumnas.asMap().entries.map((entry) {
                  int index = entry.key;
                  Alumna alumna = entry.value;
                  final bool? llego = alumna.llego;

                  return GestureDetector(
                    onTap: () => _mostrarDialogoLlegada(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: llego == null
                            ? null
                            : LinearGradient(
                                colors: llego
                                    ? [Colors.green.shade100, Colors.green.shade200]
                                    : [Colors.red.shade100, Colors.red.shade200],
                              ),
                        color: llego == null ? Colors.white : null,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(shape: BoxShape.circle),
                            child: ClipOval(
                              child: Image.asset('assets/images/inscripcion.png', fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alumna.nombre,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alumna.servicio,
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(
                                llego == true
                                    ? Icons.check_circle
                                    : llego == false
                                        ? Icons.cancel
                                        : Icons.help_outline,
                                color: llego == true
                                    ? Colors.green
                                    : llego == false
                                        ? Colors.red
                                        : Colors.grey,
                                size: 28,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "\$${alumna.anticipo.toStringAsFixed(0)}",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 20),

                // Botón Exportar Excel
                GestureDetector(
                  onTap: _exportarExcel,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: Text(
                        "Exportar Archivo",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Barra inferior como en OptionsView
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: SizedBox(
              height: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => OptionsView()),
                      );
                    },
                    child: const BottomIcon(icon: Icons.home, label: "Principal"),
                  ),
                  const BottomIcon(icon: Icons.person, label: "Mi Perfil"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BottomIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const BottomIcon({required this.icon, required this.label, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 45),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 22),
        ),
      ],
    );
  }
}
