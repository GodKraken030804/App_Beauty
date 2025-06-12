import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:shared_preferences/shared_preferences.dart';
<<<<<<< HEAD
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:typed_data';
=======
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
>>>>>>> origin/Jorge_Molina
import '../models/alumna_model.dart';
import 'dart:io' as io; // Solo se usa en móviles

class AccesoAlumnasView extends StatefulWidget {
  const AccesoAlumnasView({super.key});

  @override
  State<AccesoAlumnasView> createState() => _AccesoAlumnasViewState();
}

class _AccesoAlumnasViewState extends State<AccesoAlumnasView> {
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

  Future<void> _guardarAlumnas(List<Alumna> lista) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = lista.map((a) => a.toJson()).toList();
    prefs.setString('alumnas_guardadas', jsonEncode(jsonList));
  }

  Future<void> _importarExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true, // Necesario para web
    );

    if (result != null) {
      Uint8List? bytes;

      if (kIsWeb) {
        bytes = result.files.first.bytes;
<<<<<<< HEAD
      } else {
        final path = result.files.first.path;
        if (path != null) {
          bytes = await io.File(path).readAsBytes();
        }
      }

      if (bytes != null) {
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
        }
=======
>>>>>>> origin/Jorge_Molina
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
      }
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
    final mainColor = const Color.fromARGB(255, 195, 19, 142).withOpacity(0.9);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Acceso de Alumnas'),
        backgroundColor: mainColor,
        elevation: 4,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: _importarExcel,
              icon: const Icon(Icons.upload_file),
              label: const Text('Subir Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: alumnas.length,
              itemBuilder: (context, index) {
                final alumna = alumnas[index];
                return GestureDetector(
                  onTap: () => _mostrarDialogoLlegada(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: alumna.llego == null
                          ? Colors.grey[100]
                          : alumna.llego!
                              ? Colors.green[100]
                              : Colors.red[100],
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
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alumna.nombre,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alumna.servicio,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "Anticipo pagado",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              "\$${alumna.anticipo.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
