import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
// import 'package:jwt_decoder/jwt_decoder.dart'; // No se usa aquí
import 'package:another_flushbar/flushbar.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import '../models/alumna_model.dart';
import 'package:app_beauty/src/views/mi_perfil_view.dart';
import 'package:google_fonts/google_fonts.dart';

class AccesoAlumnasView extends StatefulWidget {
  final int? cursoId;
  final String? nombreCurso;
  final String? excel;

  const AccesoAlumnasView({
    super.key,
    this.cursoId,
    this.nombreCurso,
    this.excel,
  });

  @override
  State<AccesoAlumnasView> createState() => _AccesoAlumnasViewState();
}

class _AccesoAlumnasViewState extends State<AccesoAlumnasView>
    with TickerProviderStateMixin {
  List<Alumna> _alumnas = [];
  final Color _gradientStart = const Color(0xFFF26AB6);
  final Color _gradientEnd = const Color(0xFFAA57EC);

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  late final AnimationController _listIntroController;

  @override
  void initState() {
    super.initState();
    _loadSavedAlumnas();

    _listIntroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();

    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _listIntroController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveAlumnas(List<Alumna> lista) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = lista.map((a) => a.toJson()).toList();
    // Guardamos las alumnas con una clave única para cada curso o usando una clave general
    final key = widget.cursoId != null
        ? 'alumnas_curso_${widget.cursoId}'
        : 'alumnas_guardadas';
    await prefs.setString(key, jsonEncode(jsonList));
  }

  void _showNotification(String title, String message) {
    Flushbar(
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(12),
      backgroundColor: _gradientStart,
      flushbarPosition: FlushbarPosition.TOP,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 24),
      titleText: Text(title,
          style: const TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
      messageText: Text(message,
          style: const TextStyle(fontSize: 14, color: Colors.white)),
      duration: const Duration(seconds: 3),
    ).show(context);
  }

  Future<void> _loadSavedAlumnas() async {
    final prefs = await SharedPreferences.getInstance();
    final key = widget.cursoId != null
        ? 'alumnas_curso_${widget.cursoId}'
        : 'alumnas_guardadas';
    final data = prefs.getString(key);
    if (data != null) {
      try {
        final jsonList = jsonDecode(data) as List;
        setState(
            () => _alumnas = jsonList.map((e) => Alumna.fromJson(e)).toList());
      } catch (_) {
        if (widget.excel != null && widget.excel!.isNotEmpty) {
          _downloadAssignedExcel();
        }
      }
    } else {
      if (widget.excel != null && widget.excel!.isNotEmpty) {
        _downloadAssignedExcel();
      }
    }
  }

  // Helper: parsea bytes de un Excel (.xlsx) a lista de Alumna
  List<Alumna> _parseExcelBytes(Uint8List bytes) {
    final List<Alumna> loaded = [];
    try {
      final excel = excel_lib.Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) return loaded;
      final hoja = excel.tables[excel.tables.keys.first];
      if (hoja == null || hoja.maxRows == 0) return loaded;

      final headerRow =
          hoja.row(0).map((c) => c?.value.toString() ?? '').toList();
      final Map<String, int> idx = {};
      for (int i = 0; i < headerRow.length; i++) {
        idx[headerRow[i].toLowerCase().trim()] = i;
      }
      int? findIndexX(List<String> candidates) {
        for (var c in candidates) {
          final lowerc = c.toLowerCase();
          final match =
              idx.keys.firstWhere((k) => k.contains(lowerc), orElse: () => '');
          if (match.isNotEmpty) return idx[match];
        }
        return null;
      }

      final nombreIdx = findIndexX(['nombre', 'name']) ?? 0;
      final servicioIdx = findIndexX(['servicio', 'service']) ?? 1;
      final anticipoIdx = findIndexX(['anticipo', 'abono', 'fee']) ?? 2;
      final metodoIdx = findIndexX(
              ['método de pago', 'metodo de pago', 'metodo', 'metodo_pago']) ??
          3;
      final digitosIdx =
          findIndexX(['4 dígitos', '4 digitos', 'digitos', 'ultimos 4']) ?? 4;
      final llegoIdx = findIndexX(['llego', 'llegó', 'asistio', 'asistió']);

      for (int r = 1; r < hoja.maxRows; r++) {
        final fila = hoja.row(r).map((c) => c?.value.toString() ?? '').toList();
        String getAt(int? j) => (j != null && j < fila.length) ? fila[j] : '';

        final nombre = getAt(nombreIdx);
        final servicio = getAt(servicioIdx);
        final anticipo =
            double.tryParse(getAt(anticipoIdx).replaceAll(',', '.')) ?? 0.0;
        final metodoPago = getAt(metodoIdx);
        final digitos = getAt(digitosIdx);

        bool? llego;
        if (llegoIdx != null) {
          final lr = getAt(llegoIdx);
          if (lr.trim().isEmpty) {
            llego = false;
          } else {
            final low = lr.toLowerCase();
            llego =
                low.contains('si') || low.contains('sí') || low.contains('yes');
          }
        } else {
          llego = null;
        }

        loaded.add(Alumna(
            nombre: nombre,
            servicio: servicio,
            anticipo: anticipo,
            metodoPago: metodoPago,
            digitos: digitos,
            llego: llego));
      }
    } catch (e) {
      debugPrint('Error parseando Excel: $e');
    }
    return loaded;
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true);
    if (result == null || result.files.isEmpty) return;
    Uint8List? bytes = result.files.first.bytes;
    final filename = result.files.first.name;
    if (!kIsWeb) {
      final path = result.files.first.path;
      if ((bytes == null || bytes.isEmpty) && path != null) {
        bytes = await io.File(path).readAsBytes();
      }
    }
    if (bytes == null) return;

    try {
      final lower = filename.toLowerCase();
      final List<Alumna> loaded = [];

      if (lower.endsWith('.csv')) {
        String content;
        try {
          content = utf8.decode(bytes);
        } catch (_) {
          content = latin1.decode(bytes);
        }
        if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
          content = content.substring(1);
        }
        final rawLines = content.split(RegExp(r'\r?\n'));
        final lines = rawLines.where((l) => l.trim().isNotEmpty).toList();
        if (lines.isEmpty) return;

        final sample = lines.take(5).join('\n');
        final commaCount = RegExp(',').allMatches(sample).length;
        final semicolonCount = RegExp(';').allMatches(sample).length;
        final delim = semicolonCount > commaCount ? ';' : ',';

        List<String> parseCsvLine(String line) {
          final List<String> fields = [];
          final sb = StringBuffer();
          bool inQuotes = false;
          for (int i = 0; i < line.length; i++) {
            final ch = line[i];
            if (ch == '"') {
              if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
                sb.write('"');
                i++;
              } else {
                inQuotes = !inQuotes;
              }
            } else if (ch == delim && !inQuotes) {
              fields.add(sb.toString());
              sb.clear();
            } else {
              sb.write(ch);
            }
          }
          fields.add(sb.toString());
          return fields.map((s) => s.trim()).toList();
        }

        final header = parseCsvLine(lines.first);
        final Map<String, int> idx = {};
        for (int i = 0; i < header.length; i++) {
          idx[header[i].toLowerCase().trim()] = i;
        }

        int? findIndex(List<String> candidates) {
          for (var c in candidates) {
            final lowerc = c.toLowerCase();
            final match = idx.keys
                .firstWhere((k) => k.contains(lowerc), orElse: () => '');
            if (match.isNotEmpty) return idx[match];
          }
          return null;
        }

        final nombreIdx = findIndex(['nombre', 'name']) ?? 0;
        final servicioIdx = findIndex(['servicio', 'service']) ?? 1;
        final anticipoIdx = findIndex(['anticipo', 'abono', 'fee']) ?? 2;
        final metodoIdx = findIndex([
              'método de pago',
              'metodo de pago',
              'metodo',
              'metodo_pago'
            ]) ??
            3;
        final digitosIdx =
            findIndex(['4 dígitos', '4 digitos', 'digitos', 'ultimos 4']) ?? 4;
        final llegoIdx = findIndex(['llego', 'llegó', 'asistio', 'asistió']);

        for (int r = 1; r < lines.length; r++) {
          final row = parseCsvLine(lines[r]);
          String getAt(int? j) => (j != null && j < row.length) ? row[j] : '';

          final nombre = getAt(nombreIdx);
          final servicio = getAt(servicioIdx);
          final anticipo =
              double.tryParse(getAt(anticipoIdx).replaceAll(',', '.')) ?? 0.0;
          final metodoPago = getAt(metodoIdx);
          final digitos = getAt(digitosIdx);

          bool? llego;
          if (llegoIdx != null) {
            final lr = getAt(llegoIdx);
            if (lr.trim().isEmpty) {
              llego = false;
            } else {
              final low = lr.toLowerCase();
              llego = low.contains('si') ||
                  low.contains('sí') ||
                  low.contains('yes');
            }
          } else {
            llego = null;
          }

          loaded.add(Alumna(
              nombre: nombre,
              servicio: servicio,
              anticipo: anticipo,
              metodoPago: metodoPago,
              digitos: digitos,
              llego: llego));
        }
      } else {
        final excel = excel_lib.Excel.decodeBytes(bytes);
        final hoja = excel.tables[excel.tables.keys.first];
        if (hoja != null && hoja.maxRows > 0) {
          final headerRow =
              hoja.row(0).map((c) => c?.value.toString() ?? '').toList();
          final Map<String, int> idx = {};
          for (int i = 0; i < headerRow.length; i++) {
            idx[headerRow[i].toLowerCase().trim()] = i;
          }

          int? findIndexX(List<String> candidates) {
            for (var c in candidates) {
              final lowerc = c.toLowerCase();
              final match = idx.keys
                  .firstWhere((k) => k.contains(lowerc), orElse: () => '');
              if (match.isNotEmpty) return idx[match];
            }
            return null;
          }

          final nombreIdx = findIndexX(['nombre', 'name']) ?? 0;
          final servicioIdx = findIndexX(['servicio', 'service']) ?? 1;
          final anticipoIdx = findIndexX(['anticipo', 'abono', 'fee']) ?? 2;
          final metodoIdx = findIndexX([
                'método de pago',
                'metodo de pago',
                'metodo',
                'metodo_pago'
              ]) ??
              3;
          final digitosIdx =
              findIndexX(['4 dígitos', '4 digitos', 'digitos', 'ultimos 4']) ??
                  4;
          final llegoIdx = findIndexX(['llego', 'llegó', 'asistio', 'asistió']);

          for (int r = 1; r < hoja.maxRows; r++) {
            final fila =
                hoja.row(r).map((c) => c?.value.toString() ?? '').toList();
            String getAt(int? j) =>
                (j != null && j < fila.length) ? fila[j] : '';

            final nombre = getAt(nombreIdx);
            final servicio = getAt(servicioIdx);
            final anticipo =
                double.tryParse(getAt(anticipoIdx).replaceAll(',', '.')) ?? 0.0;
            final metodoPago = getAt(metodoIdx);
            final digitos = getAt(digitosIdx);

            bool? llego;
            if (llegoIdx != null) {
              final lr = getAt(llegoIdx);
              if (lr.trim().isEmpty) {
                llego = false;
              } else {
                final low = lr.toLowerCase();
                llego = low.contains('si') ||
                    low.contains('sí') ||
                    low.contains('yes');
              }
            } else {
              llego = null;
            }

            loaded.add(Alumna(
                nombre: nombre,
                servicio: servicio,
                anticipo: anticipo,
                metodoPago: metodoPago,
                digitos: digitos,
                llego: llego));
          }
        }
      }

      setState(() => _alumnas = loaded);
      await _saveAlumnas(loaded);
      _showNotification('Importado', 'Se importaron ${loaded.length} filas.');
    } catch (e, st) {
      debugPrint('Import error: $e');
      debugPrint(st.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al procesar el archivo')));
      }
    }
  }

  Future<void> _exportCsv() async {
    const String delim = ';';
    String escapeCsv(String s) {
      if (s.contains('"') ||
          s.contains(delim) ||
          s.contains('\n') ||
          s.contains('\r')) {
        return '"' + s.replaceAll('"', '""') + '"';
      }
      return s;
    }

    // Fecha actual disponible si se requiere en futuras columnas
    // Nombre según convención: Lista_(Ciudad)_(Mes)_Final.csv
    final _NameParts np = _deriveCityAndMonth(widget.nombreCurso);
    final filename = 'Lista_${np.city}_${np.month}_Final.csv';

    final header = [
      'Nombre',
      'Servicio',
      'Anticipo',
      'Método de pago',
      '4 Dígitos',
      'Llego'
    ];
    final lines = <String>[header.map(escapeCsv).join(delim)];
    for (var a in _alumnas) {
      final row = [
        a.nombre,
        a.servicio,
        a.anticipo.toString(),
        a.metodoPago,
        a.digitos,
        a.llego == true ? 'Sí' : (a.llego == false ? 'No' : '')
      ];
      lines.add(row.map((e) => escapeCsv(e.toString())).join(delim));
    }
    final csv = lines.join('\r\n');
    final bytesNoBOM = utf8.encode(csv);
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF] + bytesNoBOM);

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      _showNotification('Exportado', 'CSV preparado');
      return;
    }
    // Preguntar: Descargar (Descargas) o Enviar
    await _promptSaveOrSend(bytes, filename, mimeType: 'text/csv');
  }

  Future<void> _downloadAssignedExcel() async {
    if (widget.excel == null || widget.excel!.isEmpty) {
      debugPrint(
          '[AccesoAlumnas] No hay excel en el widget para cursoId=${widget.cursoId}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No hay Excel asignado para este curso')));
      }
      return;
    }

    try {
      // Usamos directamente la URL del Excel del curso actual (sanitizada)
      final rawUrl = widget.excel!;
      final url = rawUrl.trim().replaceAll(' ', '%20');
      debugPrint(
          '[AccesoAlumnas] Descargando excel desde $url (cursoId=${widget.cursoId})');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        debugPrint(
            '[AccesoAlumnas] Error HTTP ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error descargando archivo')));
        }
        return;
      }
      // Parsear según extensión y mostrar vista previa
      List<Alumna> parsed = [];
      if (url.toLowerCase().endsWith('.csv')) {
        debugPrint('[AccesoAlumnas] Detectado CSV, parseando...');
        String content;
        try {
          content = utf8.decode(resp.bodyBytes);
        } catch (_) {
          content = latin1.decode(resp.bodyBytes);
        }
        if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
          content = content.substring(1);
        }
        final rawLines = content.split(RegExp(r'\r?\n'));
        final lines = rawLines.where((l) => l.trim().isNotEmpty).toList();
        if (lines.isNotEmpty) {
          final sample = lines.take(5).join('\n');
          final commaCount = RegExp(',').allMatches(sample).length;
          final semicolonCount = RegExp(';').allMatches(sample).length;
          final delim = semicolonCount > commaCount ? ';' : ',';

          List<String> parseCsvLine(String line) {
            final List<String> fields = [];
            final sb = StringBuffer();
            bool inQuotes = false;
            for (int i = 0; i < line.length; i++) {
              final ch = line[i];
              if (ch == '"') {
                if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
                  sb.write('"');
                  i++;
                } else {
                  inQuotes = !inQuotes;
                }
              } else if (ch == delim && !inQuotes) {
                fields.add(sb.toString());
                sb.clear();
              } else {
                sb.write(ch);
              }
            }
            // Vista previa de las primeras 2 filas
            final preview = parsed.take(2).toList();
            for (int i = 0; i < preview.length; i++) {
              final a = preview[i];
              debugPrint('[AccesoAlumnas][Preview][${i + 1}] '
                  'nombre=${a.nombre}, servicio=${a.servicio}, anticipo=${a.anticipo}, '
                  'metodo=${a.metodoPago}, digitos=${a.digitos}, llego=${a.llego}');
            }
            fields.add(sb.toString());
            return fields.map((s) => s.trim()).toList();
          }

          final header = parseCsvLine(lines.first);
          final Map<String, int> idx = {};
          for (int i = 0; i < header.length; i++) {
            idx[header[i].toLowerCase().trim()] = i;
          }
          int? findIndex(List<String> candidates) {
            for (var c in candidates) {
              final lowerc = c.toLowerCase();
              final match = idx.keys
                  .firstWhere((k) => k.contains(lowerc), orElse: () => '');
              if (match.isNotEmpty) return idx[match];
            }
            return null;
          }

          final nombreIdx = findIndex(['nombre', 'name']) ?? 0;
          final servicioIdx = findIndex(['servicio', 'service']) ?? 1;
          final anticipoIdx = findIndex(['anticipo', 'abono', 'fee']) ?? 2;
          final metodoIdx = findIndex([
                'método de pago',
                'metodo de pago',
                'metodo',
                'metodo_pago'
              ]) ??
              3;
          final digitosIdx =
              findIndex(['4 dígitos', '4 digitos', 'digitos', 'ultimos 4']) ??
                  4;
          final llegoIdx = findIndex(['llego', 'llegó', 'asistio', 'asistió']);

          for (int r = 1; r < lines.length; r++) {
            final row = parseCsvLine(lines[r]);
            String getAt(int? j) => (j != null && j < row.length) ? row[j] : '';
            bool? llego;
            if (llegoIdx != null) {
              final lr = getAt(llegoIdx);
              if (lr.trim().isEmpty) {
                llego = false;
              } else {
                final low = lr.toLowerCase();
                llego = low.contains('si') ||
                    low.contains('sí') ||
                    low.contains('yes');
              }
            }
            parsed.add(Alumna(
              nombre: getAt(nombreIdx),
              servicio: getAt(servicioIdx),
              anticipo:
                  double.tryParse(getAt(anticipoIdx).replaceAll(',', '.')) ??
                      0.0,
              metodoPago: getAt(metodoIdx),
              digitos: getAt(digitosIdx),
              llego: llego,
            ));
          }
        }
      } else {
        debugPrint('[AccesoAlumnas] Detectado XLSX, parseando...');
        parsed = _parseExcelBytes(resp.bodyBytes);
      }
      if (parsed.isNotEmpty) {
        setState(() => _alumnas = parsed);
        await _saveAlumnas(parsed);
        debugPrint(
            '[AccesoAlumnas] Cargadas ${parsed.length} alumnas para cursoId=${widget.cursoId}');
      }

      // Nombre según convención: Lista_(Ciudad)_(Mes)_Nueva.<ext>
      final _NameParts np = _deriveCityAndMonth(widget.nombreCurso);
      final isCsv = url.toLowerCase().endsWith('.csv');
      final filename =
          'Lista_${np.city}_${np.month}_Nueva${isCsv ? '.csv' : '.xlsx'}';
      if (kIsWeb) {
        final blob = html.Blob([resp.bodyBytes]);
        final u = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: u)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(u);
        return;
      }
      // Mostrar opciones: Descargar (Descargas) o Enviar
      await _promptSaveOrSend(
        resp.bodyBytes,
        filename,
        mimeType: isCsv
            ? 'text/csv'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e, st) {
      debugPrint('Download error: $e');
      debugPrint(st.toString());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _promptSaveDownloaded(Uint8List bytes, String filename,
      {required String mimeType}) async {}

  Future<void> _promptSaveOrSend(Uint8List bytes, String filename,
      {required String mimeType}) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('¿Qué deseas hacer?',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final ok = await _saveToDownloads(bytes, filename,
                            mimeType: mimeType);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _showNotification(ok ? 'Guardado' : 'Error',
                            ok ? 'Archivo en Descargas' : 'No se pudo guardar');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ).merge(ButtonStyle(
                        shape: MaterialStateProperty.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                        elevation: MaterialStateProperty.all(0),
                      )),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [_gradientStart, _gradientEnd]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('Descargar',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          final tempDir = await getTemporaryDirectory();
                          final tempFile = io.File('${tempDir.path}/$filename');
                          await tempFile.writeAsBytes(bytes, flush: true);
                          await Share.shareXFiles([
                            XFile(tempFile.path, name: filename),
                          ]);
                        } catch (_) {
                          _showNotification('Error', 'No se pudo compartir');
                        }
                        if (!mounted) return;
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _gradientStart),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Enviar/Compartir',
                          style: GoogleFonts.poppins(
                              color: _gradientStart,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveWithPicker(Uint8List bytes, String filename) async {
    // Separa nombre y extensión para FileSaver (respaldo si se requiere)
    final dot = filename.lastIndexOf('.');
    String base = filename;
    String ext = '';
    if (dot != -1 && dot < filename.length - 1) {
      base = filename.substring(0, dot);
      ext = filename.substring(dot + 1);
    }
    // Usa el selector del sistema (SAF en Android)
    await FileSaver.instance.saveFile(
      name: base,
      ext: ext,
      bytes: bytes,
      mimeType: MimeType.other,
    );
  }

  Future<bool> _saveToDownloads(Uint8List bytes, String filename,
      {required String mimeType}) async {
    // Guardar vía FileSaver en Descargas (MediaStore). Requiere ext separada.
    final dot = filename.lastIndexOf('.');
    String base = filename;
    String ext = '';
    if (dot != -1 && dot < filename.length - 1) {
      base = filename.substring(0, dot);
      ext = filename.substring(dot + 1);
    }
    try {
      final savedPath = await FileSaver.instance.saveFile(
        name: base,
        ext: ext,
        bytes: bytes,
        mimeType: MimeType.other,
      );
      return savedPath.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Guarda en una carpeta segura de la app: Android => /Android/data/<paquete>/files/AppBeauty
  // iOS => Documents/AppBeauty. No requiere permisos especiales.
  Future<io.File> _createFileInAppFolder(String filename) async {
    if (io.Platform.isAndroid) {
      final baseDir = await getExternalStorageDirectory();
      if (baseDir == null) {
        // Fallback a documentos internos si algo falla
        final docs = await getApplicationDocumentsDirectory();
        final appDir = io.Directory('${docs.path}/AppBeauty');
        if (!await appDir.exists()) await appDir.create(recursive: true);
        return io.File('${appDir.path}/$filename');
      }
      final appDir = io.Directory('${baseDir.path}/AppBeauty');
      if (!await appDir.exists()) await appDir.create(recursive: true);
      return io.File('${appDir.path}/$filename');
    } else {
      final docs = await getApplicationDocumentsDirectory();
      final appDir = io.Directory('${docs.path}/AppBeauty');
      if (!await appDir.exists()) await appDir.create(recursive: true);
      return io.File('${appDir.path}/$filename');
    }
  }

  void _showAttendanceDialog(int index) {
    String metodo = _alumnas[index].metodoPago;
    String dig = _alumnas[index].digitos;
    bool showDig =
        metodo.contains('Transferencia') || metodo.contains('Tarjeta');
    final formKey = GlobalKey<FormState>();

    final List<_PayOption> options = [
      _PayOption('Efectivo', Icons.payments_rounded, Colors.green),
      _PayOption('Transferencia', Icons.account_balance, Colors.blueAccent),
      _PayOption('Tarjeta', Icons.credit_card, Colors.deepPurple),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateD) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/Logo.png',
                        height: 42,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Asistencia',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _gradientEnd,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¿${_alumnas[index].nombre} asistió?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonFormField<String>(
                            value: metodo.isEmpty ? null : metodo,
                            decoration: const InputDecoration(
                              labelText: 'Método de pago',
                              border: InputBorder.none,
                              labelStyle: TextStyle(color: Colors.grey),
                            ),
                            items: options
                                .map((o) => DropdownMenuItem<String>(
                                      value: o.label,
                                      child: Row(
                                        children: [
                                          Icon(o.icon,
                                              size: 18, color: o.color),
                                          const SizedBox(width: 8),
                                          Text(o.label,
                                              style: GoogleFonts.poppins()),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setStateD(() {
                              metodo = v ?? '';
                              showDig = metodo.contains('Transferencia') ||
                                  metodo.contains('Tarjeta');
                            }),
                          ),
                        ),
                        if (showDig) const SizedBox(height: 12),
                        if (showDig)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextFormField(
                              initialValue: dig,
                              maxLength: 4,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Últimos 4 dígitos',
                                border: InputBorder.none,
                                labelStyle: const TextStyle(color: Colors.grey),
                                counterText: '',
                                prefixIcon: Icon(
                                  metodo.contains('Tarjeta')
                                      ? Icons.credit_card
                                      : Icons.swap_horiz,
                                  color: _gradientEnd,
                                ),
                              ),
                              onChanged: (v) => dig = v,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: () async {
                              setState(() {
                                _alumnas[index].llego = false;
                                _alumnas[index].metodoPago = metodo;
                                _alumnas[index].digitos = showDig ? dig : '';
                              });
                              await _saveAlumnas(_alumnas);
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('No', style: GoogleFonts.poppins()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_gradientStart, _gradientEnd],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: () async {
                              setState(() {
                                _alumnas[index].llego = true;
                                _alumnas[index].metodoPago = metodo;
                                _alumnas[index].digitos = showDig ? dig : '';
                              });
                              await _saveAlumnas(_alumnas);
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Sí', style: GoogleFonts.poppins()),
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Alumna> filtered = _query.isEmpty
        ? _alumnas
        : _alumnas.where((a) {
            final q = _query;
            return a.nombre.toLowerCase().contains(q) ||
                a.servicio.toLowerCase().contains(q) ||
                a.metodoPago.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      body: Column(
        children: [
          // Top gradient bar (same style used in Registrar/Asignacion)
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
          const SizedBox(height: 8),
          // Header: big logo, course title, then search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/Logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.nombreCurso ?? 'Lista de Alumnas',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: _gradientStart,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSearchBar(),
              ],
            ),
          ),
          Expanded(
            child: _alumnas.isEmpty
                ? _buildEmptyState()
                : _buildAnimatedList(filtered),
          ),
        ],
      ),
      // Floating actions: menú hamburguesa que despliega 3 acciones con texto e icono
      floatingActionButton: _FabSpeedMenu(
        primary: FloatingActionButton(
          onPressed: () {},
          backgroundColor: _gradientEnd,
          child: const Icon(Icons.menu, color: Colors.white),
        ),
        items: [
          FabItem(
            label: 'Descargar asignada',
            icon: Icons.file_download_outlined,
            onTap: _downloadAssignedExcel,
          ),
          FabItem(
            label: 'Importar lista',
            icon: Icons.upload_file,
            onTap: _importFile,
          ),
          FabItem(
            label: 'Exportar CSV final',
            icon: Icons.table_view,
            onTap: _exportCsv,
          ),
        ],
        gradientStart: _gradientStart,
        gradientEnd: _gradientEnd,
      ),
      // Barra inferior: igual a CursosAdministradores (Inicio flecha atrás y Mi Perfil)
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
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
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'Buscar por nombre, servicio o método de pago...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: _gradientStart),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: _gradientStart, width: 1.5),
          ),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.close, color: Colors.grey),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAnimatedList(List<Alumna> list) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final a = list[index];
        final _StatusVisual sVisual = _statusFor(a.llego);
        final double start = (index.clamp(0, 8) as int) * 0.06;
        final double end = start + 0.6;

        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _listIntroController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _listIntroController,
              curve: Interval(start, end, curve: Curves.easeOutCubic),
            )),
            child: _AlumnoCard(
              alumna: a,
              onTap: () => _showAttendanceDialog(_alumnas.indexOf(a)),
              status: sVisual,
              gradientStart: _gradientStart,
              gradientEnd: _gradientEnd,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: 0.75,
                child: Image.asset(
                  'assets/images/inscripcion.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Text(
              'No hay alumnas cargadas',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // Gastos-style gradient square button for actions
  Widget _buildGradientSquareButton({
    required IconData icon,
    required VoidCallback onTap,
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
            colors: [_gradientStart, _gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: borderRadius,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(child: Icon(icon, color: Colors.white, size: 30)),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_gradientStart, _gradientEnd],
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
            icon: Icon(Icons.arrow_back),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Mi Perfil',
          ),
        ],
      ),
    );
  }

  // Removed old expandable FAB menu in favor of three square actions

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  _StatusVisual _statusFor(bool? llego) {
    if (llego == true) {
      return _StatusVisual(
        bgStart: const Color(0xFF2ECC71),
        bgEnd: const Color(0xFF27AE60),
        chipColor: const Color(0xFF2ECC71),
        icon: Icons.check_circle,
        iconColor: const Color(0xFF1B5E20),
        label: 'Asistió',
      );
    } else if (llego == false) {
      return _StatusVisual(
        bgStart: const Color(0xFFE57373),
        bgEnd: const Color(0xFFE53935),
        chipColor: const Color(0xFFE53935),
        icon: Icons.cancel_rounded,
        iconColor: const Color(0xFFB71C1C),
        label: 'No asistió',
      );
    } else {
      return _StatusVisual(
        bgStart: Colors.grey.shade100,
        bgEnd: Colors.grey.shade200,
        chipColor: Colors.grey.shade400,
        icon: Icons.radio_button_unchecked,
        iconColor: Colors.grey.shade600,
        label: 'Pendiente',
      );
    }
  }
}

// Helpers para crear nombres de archivo bonitos
class _NameParts {
  final String city;
  final String month;
  _NameParts(this.city, this.month);
}

_NameParts _deriveCityAndMonth(String? courseName) {
  final now = DateTime.now();
  final meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre'
  ];
  final month = meses[now.month - 1];

  // Ahora usamos el nombre completo del curso como parte del archivo
  String city = (courseName ?? '').toString().trim();
  if (city.isEmpty) city = 'SinCurso';

  String _removeAccents(String input) {
    const withAccents =
        'áàäâãÁÀÄÂÃéèëêÉÈËÊíìïîÍÌÏÎóòöôõÓÒÖÔÕúùüûÚÙÜÛñÑçÇ()[]{}';
    const without = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUnNcC      ';
    String out = input;
    for (int i = 0; i < withAccents.length && i < without.length; i++) {
      out = out.replaceAll(withAccents[i], without[i]);
    }
    return out;
  }

  String sanitize(String s) => _removeAccents(s)
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  return _NameParts(sanitize(city), sanitize(month));
}

class _AlumnoCard extends StatefulWidget {
  final Alumna alumna;
  final VoidCallback onTap;
  final _StatusVisual status;
  final Color gradientStart;
  final Color gradientEnd;

  const _AlumnoCard({
    Key? key,
    required this.alumna,
    required this.onTap,
    required this.status,
    required this.gradientStart,
    required this.gradientEnd,
  }) : super(key: key);

  @override
  State<_AlumnoCard> createState() => _AlumnoCardState();
}

class _AlumnoCardState extends State<_AlumnoCard> {
  @override
  Widget build(BuildContext context) {
    final a = widget.alumna;
    final s = widget.status;
    final width = MediaQuery.of(context).size.width;
    final bool isWide = width > 420;
    final bool showDigits =
        (a.metodoPago == 'Tarjeta' || a.metodoPago == 'Transferencia') &&
            a.digitos.isNotEmpty;
    final String paymentInfo = a.metodoPago.isNotEmpty
        ? '${a.metodoPago}${showDigits ? ' (${a.digitos})' : ''}'
        : '';

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: a.llego == null
                ? [Colors.white, Colors.white]
                : [s.bgStart.withOpacity(0.08), s.bgEnd.withOpacity(0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: a.llego == null
                ? Colors.grey.shade200
                : s.bgStart.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/inscripcion.png',
                    width: isWide ? 54 : 46,
                    height: isWide ? 54 : 46,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.servicio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (paymentInfo.isNotEmpty) const SizedBox(height: 4),
                      if (paymentInfo.isNotEmpty)
                        Text(
                          paymentInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (a.llego == null
                                  ? Colors.grey.shade300
                                  : s.chipColor)
                              .withOpacity(0.18),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: (a.llego == null
                                    ? Colors.grey.shade400
                                    : s.chipColor)
                                .withOpacity(0.7),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              s.icon,
                              size: 16,
                              color: a.llego == null
                                  ? Colors.grey.shade600
                                  : s.chipColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.label,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: a.llego == null
                                    ? Colors.grey.shade700
                                    : s.chipColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (a.llego == null
                          ? Colors.grey.shade200
                          : s.bgStart.withOpacity(0.4)),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${a.anticipo.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: isWide ? 22 : 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        a.llego == null
                            ? Icons.help_outline
                            : (a.llego! ? Icons.check_circle : Icons.cancel),
                        size: isWide ? 26 : 24,
                        color: a.llego == null ? Colors.grey[400] : s.iconColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusVisual {
  final Color bgStart;
  final Color bgEnd;
  final Color chipColor;
  final IconData icon;
  final Color iconColor;
  final String label;

  _StatusVisual({
    required this.bgStart,
    required this.bgEnd,
    required this.chipColor,
    required this.icon,
    required this.iconColor,
    required this.label,
  });
}

class _PayOption {
  final String label;
  final IconData icon;
  final Color color;
  const _PayOption(this.label, this.icon, this.color);
}

class _FabSpeedMenu extends StatefulWidget {
  final FloatingActionButton primary;
  final List<FabItem> items;
  final Color gradientStart;
  final Color gradientEnd;

  const _FabSpeedMenu({
    Key? key,
    required this.primary,
    required this.items,
    required this.gradientStart,
    required this.gradientEnd,
  }) : super(key: key);

  @override
  State<_FabSpeedMenu> createState() => _FabSpeedMenuState();
}

class _FabSpeedMenuState extends State<_FabSpeedMenu>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              child: FadeTransition(
                opacity: _opacity,
                child: Container(color: Colors.black54.withOpacity(0.25)),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizeTransition(
                sizeFactor: _opacity,
                axisAlignment: -1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: widget.items
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ScaleTransition(
                            scale: _scale,
                            child: _MiniActionChip(
                              label: e.label,
                              icon: e.icon,
                              onTap: () {
                                _toggle();
                                e.onTap();
                              },
                              gradientStart: widget.gradientStart,
                              gradientEnd: widget.gradientEnd,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              FloatingActionButton(
                onPressed: _toggle,
                backgroundColor: widget.gradientEnd,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    _open ? Icons.close : Icons.add,
                    key: ValueKey(_open),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FabItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  FabItem({required this.label, required this.icon, required this.onTap});
}

class _MiniActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color gradientStart;
  final Color gradientEnd;

  const _MiniActionChip({
    Key? key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.gradientStart,
    required this.gradientEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientStart, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
