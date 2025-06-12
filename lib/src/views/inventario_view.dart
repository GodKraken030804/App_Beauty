import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as flutter;

class ProductosExcelView extends StatefulWidget {
  const ProductosExcelView({super.key});

  @override
  State<ProductosExcelView> createState() => _ProductosExcelViewState();
}

class _ProductosExcelViewState extends State<ProductosExcelView> {
  List<Map<String, String>> productos = [];

  Future<void> _importarExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
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

      if (bytes == null) return;

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null) return;

      List<Map<String, String>> lista = [];

      for (int i = 1; i < sheet.maxRows; i++) {
        final fila = sheet.row(i);
        lista.add({
          'producto': fila[0]?.value.toString() ?? '',
          'precio': (fila[1]?.value is double)
              ? '\$${(fila[1]!.value as double).toStringAsFixed(2)}'
              : (fila[1]?.value is DateTime)
                  ? 'Formato inválido'
                  : fila[1]?.value.toString() ?? '',
          'codigo': fila[2]?.value.toString() ?? '',
          'barra': fila[3]?.value.toString() ?? '',
        });
      }

      setState(() {
        productos = lista;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos desde Excel')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _importarExcel,
            child: const Text('Subir Excel'),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: productos.map((p) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 195, 19, 142).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: flutter.Border.all(color: Colors.pinkAccent.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Producto: ${p['producto']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Precio: ${p['precio']}'),
                      Text('Código de producto: ${p['codigo']}'),
                      Text('Código de barras: ${p['barra']}'),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
