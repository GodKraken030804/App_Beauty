import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:file_saver/file_saver.dart';
import 'package:universal_html/html.dart' as html;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app_beauty/src/views/mi_perfil_view.dart';

class Ingreso {
  final String nombre;
  final double monto;
  final String descripcion;
  final Map<String, dynamic> metodosPago; // Mapa con método -> {monto, last4}
  final DateTime fecha;

  Ingreso({
    required this.nombre,
    required this.monto,
    required this.descripcion,
    required this.metodosPago,
    required this.fecha,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'monto': monto,
        'descripcion': descripcion,
        'metodosPago': metodosPago,
        'fecha': fecha.toIso8601String(),
      };

  factory Ingreso.fromJson(Map<String, dynamic> json) {
    // Compatibilidad hacia atrás con el formato antiguo
    Map<String, dynamic> metodosPago;
    if (json.containsKey('metodosPago')) {
      metodosPago = Map<String, dynamic>.from(json['metodosPago']);
    } else {
      // Formato antiguo: convertir metodo y last4 a nuevo formato
      final metodo = json['metodo'] as String;
      final last4 = json['last4'] as String?;
      final monto = (json['monto'] as num).toDouble();
      metodosPago = {
        metodo: {
          'monto': monto,
          if (last4 != null && last4.isNotEmpty) 'last4': last4,
        }
      };
    }

    return Ingreso(
      nombre: json['nombre'],
      monto: (json['monto'] as num).toDouble(),
      descripcion: json['descripcion'],
      metodosPago: metodosPago,
      fecha: DateTime.parse(json['fecha']),
    );
  }
}

class IngresosView extends StatefulWidget {
  final Map<String, dynamic> curso;

  const IngresosView({super.key, required this.curso});

  @override
  State<IngresosView> createState() => _IngresosViewState();
}

class _IngresosViewState extends State<IngresosView>
    with TickerProviderStateMixin {
  List<Ingreso> _ingresos = [];
  double _total = 0.0;
  final Color gradientStart = const Color(0xFFF26AB6);
  final Color gradientEnd = const Color(0xFFAA57EC);

  late final AnimationController _listIntroController;

  @override
  void initState() {
    super.initState();
    _loadIngresos();

    _listIntroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _listIntroController.dispose();
    super.dispose();
  }

  String get _prefsKey => 'ingresos_${widget.curso['id']}';

  Future<void> _loadIngresos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_prefsKey);
    if (data != null) {
      try {
        final jsonList = jsonDecode(data) as List;
        setState(() {
          _ingresos = jsonList.map((e) => Ingreso.fromJson(e)).toList();
          _total = _ingresos.fold(0.0, (sum, i) => sum + i.monto);
        });
      } catch (_) {}
    }
  }

  Future<void> _saveIngresos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _ingresos.map((i) => i.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }

  void _showNotification(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 50),
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

  void _showAddIngresoDialog() {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();
    // Controladores para métodos de pago múltiples
    final montosControllers = {
      'Efectivo': TextEditingController(),
      'Tarjeta': TextEditingController(),
      'Transferencia': TextEditingController(),
    };
    final last4Ctrl = TextEditingController();
    final last4TransferenciaCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final bottom = MediaQuery.of(context).viewInsets.bottom;
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/Logo.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'Registrar ingreso',
                            style: GoogleFonts.poppins(
                              color: gradientStart,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Nombre del ingreso
                        TextField(
                          controller: nombreController,
                          decoration: InputDecoration(
                            labelText: 'Nombre del ingreso',
                            hintText: 'Ej. Venta de material',
                            labelStyle: GoogleFonts.poppins(
                                color: Colors.grey[600], fontSize: 14),
                            hintStyle: GoogleFonts.poppins(
                                color: Colors.grey[400], fontSize: 14),
                            prefixIcon: const Icon(Icons.trending_up,
                                color: Color(0xFFF26AB6)),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: gradientStart, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                          ),
                          style: GoogleFonts.poppins(fontSize: 15),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        // Descripción
                        TextField(
                          controller: descripcionController,
                          decoration: InputDecoration(
                            labelText: 'Descripción del ingreso',
                            hintText: 'Ej. Venta de kits',
                            labelStyle: GoogleFonts.poppins(
                                color: Colors.grey[600], fontSize: 14),
                            hintStyle: GoogleFonts.poppins(
                                color: Colors.grey[400], fontSize: 14),
                            prefixIcon: const Icon(Icons.description,
                                color: Color(0xFFF26AB6)),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: gradientStart, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                          ),
                          style: GoogleFonts.poppins(fontSize: 15),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        // Métodos de Pago Múltiples
                        Text('Métodos de Pago',
                            style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              // Efectivo
                              Row(
                                children: [
                                  const Icon(Icons.attach_money,
                                      size: 20, color: Color(0xFFF26AB6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Efectivo',
                                        style:
                                            GoogleFonts.poppins(fontSize: 14)),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: montosControllers['Efectivo'],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style: GoogleFonts.poppins(fontSize: 14),
                                      decoration: InputDecoration(
                                        prefixText: '\$',
                                        hintText: '0.00',
                                        hintStyle: GoogleFonts.poppins(
                                            color: Colors.grey.shade400),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Tarjeta
                              Row(
                                children: [
                                  const Icon(Icons.credit_card,
                                      size: 20, color: Color(0xFFF26AB6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Tarjeta',
                                            style: GoogleFonts.poppins(
                                                fontSize: 14)),
                                        if ((double.tryParse(montosControllers[
                                                        'Tarjeta']!
                                                    .text
                                                    .trim()) ??
                                                0.0) >
                                            0)
                                          SizedBox(
                                            width: 100,
                                            child: TextField(
                                              controller: last4Ctrl,
                                              maxLength: 4,
                                              keyboardType:
                                                  TextInputType.number,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12),
                                              decoration: InputDecoration(
                                                counterText: '',
                                                hintText: 'Últimos 4',
                                                hintStyle: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.grey.shade400),
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 4),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                              ),
                                              onChanged: (v) {
                                                if (v.length > 4) {
                                                  last4Ctrl.text =
                                                      v.substring(0, 4);
                                                  last4Ctrl.selection =
                                                      TextSelection.fromPosition(
                                                          const TextPosition(
                                                              offset: 4));
                                                }
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: montosControllers['Tarjeta'],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style: GoogleFonts.poppins(fontSize: 14),
                                      decoration: InputDecoration(
                                        prefixText: '\$',
                                        hintText: '0.00',
                                        hintStyle: GoogleFonts.poppins(
                                            color: Colors.grey.shade400),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onChanged: (v) {
                                        setLocalState(
                                            () {}); // Actualizar UI para mostrar campo de últimos 4
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Transferencia
                              Row(
                                children: [
                                  const Icon(Icons.swap_horiz,
                                      size: 20, color: Color(0xFFF26AB6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Transferencia',
                                            style: GoogleFonts.poppins(
                                                fontSize: 14)),
                                        if ((double.tryParse(montosControllers[
                                                        'Transferencia']!
                                                    .text
                                                    .trim()) ??
                                                0.0) >
                                            0)
                                          SizedBox(
                                            width: 100,
                                            child: TextField(
                                              controller:
                                                  last4TransferenciaCtrl,
                                              maxLength: 4,
                                              keyboardType:
                                                  TextInputType.number,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12),
                                              decoration: InputDecoration(
                                                counterText: '',
                                                hintText: 'Últimos 4',
                                                hintStyle: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.grey.shade400),
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 4),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                              ),
                                              onChanged: (v) {
                                                if (v.length > 4) {
                                                  last4TransferenciaCtrl.text =
                                                      v.substring(0, 4);
                                                  last4TransferenciaCtrl
                                                          .selection =
                                                      TextSelection.fromPosition(
                                                          const TextPosition(
                                                              offset: 4));
                                                }
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller:
                                          montosControllers['Transferencia'],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style: GoogleFonts.poppins(fontSize: 14),
                                      decoration: InputDecoration(
                                        prefixText: '\$',
                                        hintText: '0.00',
                                        hintStyle: GoogleFonts.poppins(
                                            color: Colors.grey.shade400),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onChanged: (v) {
                                        setLocalState(
                                            () {}); // Actualizar UI para mostrar campo de últimos 4
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                ),
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [gradientStart, gradientEnd],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    final nombre = nombreController.text.trim();
                                    final descripcion =
                                        descripcionController.text.trim();

                                    if (nombre.isEmpty || descripcion.isEmpty) {
                                      return;
                                    }

                                    // Recopilar métodos de pago activos
                                    final metodosPago = <String, dynamic>{};
                                    double montoTotal = 0.0;

                                    for (var metodo in montosControllers.keys) {
                                      final montoStr =
                                          montosControllers[metodo]!
                                              .text
                                              .trim();
                                      if (montoStr.isNotEmpty) {
                                        final monto = double.tryParse(montoStr
                                                .replaceAll(',', '.')) ??
                                            0.0;
                                        if (monto > 0) {
                                          final metodoPagoData =
                                              <String, dynamic>{'monto': monto};

                                          // Agregar last4 si es Tarjeta o Transferencia
                                          if (metodo == 'Tarjeta') {
                                            final last4 = last4Ctrl.text.trim();
                                            if (last4.length == 4) {
                                              metodoPagoData['last4'] = last4;
                                            }
                                          } else if (metodo ==
                                              'Transferencia') {
                                            final last4 = last4TransferenciaCtrl
                                                .text
                                                .trim();
                                            if (last4.length == 4) {
                                              metodoPagoData['last4'] = last4;
                                            }
                                          }

                                          metodosPago[metodo] = metodoPagoData;
                                          montoTotal += monto;
                                        }
                                      }
                                    }

                                    if (metodosPago.isEmpty ||
                                        montoTotal <= 0) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Debes ingresar al menos un método de pago con monto válido',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor:
                                              Colors.orange.shade400,
                                        ),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      _ingresos.add(Ingreso(
                                        nombre: nombre,
                                        monto: montoTotal,
                                        descripcion: descripcion,
                                        metodosPago: metodosPago,
                                        fecha: DateTime.now(),
                                      ));
                                      _total += montoTotal;
                                    });
                                    _saveIngresos();
                                    Navigator.pop(context);
                                    _showNotification('Ingreso Agregado',
                                        'El ingreso se ha registrado correctamente.');
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Agregar',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _spanishMonth(int month) {
    const meses = [
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
    return meses[(month - 1).clamp(0, 11)];
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

    final now = DateTime.now();
    final mes = _spanishMonth(now.month);
    final filename = 'Ingresos_${mes}.csv';
    final header = [
      'Fecha',
      'Nombre',
      'Monto Total',
      'Descripción',
      'Efectivo',
      'Tarjeta',
      'Transferencia',
      'Tarjeta (Últimos 4)',
      'Transferencia (Últimos 4)',
    ];
    final lines = <String>[header.map(escapeCsv).join(delim)];
    for (var i in _ingresos) {
      final efectivoMonto =
          i.metodosPago['Efectivo']?['monto']?.toString() ?? '0.00';
      final tarjetaMonto =
          i.metodosPago['Tarjeta']?['monto']?.toString() ?? '0.00';
      final tarjetaLast4 = i.metodosPago['Tarjeta']?['last4']?.toString() ?? '';
      final transferenciaMonto =
          i.metodosPago['Transferencia']?['monto']?.toString() ?? '0.00';
      final transferenciaLast4 =
          i.metodosPago['Transferencia']?['last4']?.toString() ?? '';

      final row = [
        i.fecha.toIso8601String(),
        i.nombre,
        i.monto.toString(),
        i.descripcion,
        efectivoMonto,
        tarjetaMonto,
        transferenciaMonto,
        tarjetaLast4,
        transferenciaLast4,
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
      _showExportConfirmation();
      return;
    }

    await _promptSaveOrSend(bytes, filename, mimeType: 'text/csv');
  }

  Future<void> _promptSaveOrSend(Uint8List bytes, String filename,
      {String mimeType = 'application/octet-stream'}) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        _showNotification(
                            ok ? 'Guardado' : 'Error',
                            ok
                                ? 'Archivo guardado en Descargas.'
                                : 'No se pudo guardar.');
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
                              colors: [gradientStart, gradientEnd]),
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
                        await _shareBytes(bytes, filename);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: gradientStart),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Enviar/Compartir',
                          style: GoogleFonts.poppins(
                              color: gradientStart,
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

  Future<bool> _saveToDownloads(Uint8List bytes, String filename,
      {String mimeType = 'application/octet-stream'}) async {
    try {
      final dot = filename.lastIndexOf('.');
      final name = dot > 0 ? filename.substring(0, dot) : filename;
      final ext = dot > 0 ? filename.substring(dot + 1) : '';
      final res = await FileSaver.instance.saveFile(
        name: name,
        ext: ext,
        bytes: bytes,
        mimeType: ext.toLowerCase() == 'csv' ? MimeType.text : MimeType.other,
      );
      return res.toString().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _shareBytes(Uint8List bytes, String filename) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$filename';
      final file = io.File(path);
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(path)],
          subject: 'Ingresos', text: 'Ingresos exportados');
    } catch (_) {
      _showNotification('Error', 'No se pudo compartir el archivo.');
    }
  }

  void _showExportConfirmation() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Exportado Exitosamente',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¿Desea reiniciar la lista de ingresos para este curso?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('No'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [gradientStart, gradientEnd],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: () async {
                          setState(() {
                            _ingresos.clear();
                            _total = 0.0;
                          });
                          await _saveIngresos();
                          if (mounted) Navigator.pop(context);
                          _showNotification('Lista Reiniciada',
                              'La lista de ingresos ha sido reiniciada.');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Sí'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.18),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Image.asset('assets/images/Logo.png', height: 60),
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up, color: Color(0xFFF26AB6)),
                      const SizedBox(width: 8),
                      Text(
                        'Total de Ingresos',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '\$${_total.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                        fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _ingresos.isEmpty
                ? Center(
                    child: Text(
                      'No hay ingresos registrados',
                      style:
                          GoogleFonts.poppins(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _ingresos.length,
                    itemBuilder: (context, index) {
                      final i = _ingresos[index];
                      final double start = index.clamp(0, 8) * 0.06;
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
                            curve: Interval(start, end,
                                curve: Curves.easeOutCubic),
                          )),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long,
                                  color: Color(0xFFF26AB6)),
                              title: Text(i.nombre,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monto Total: \$${i.monto.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Descripción: ${i.descripcion}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 14, color: Colors.black87),
                                  ),
                                  // Mostrar todos los métodos de pago
                                  ...i.metodosPago.entries.map((entry) {
                                    final metodo = entry.key;
                                    final info =
                                        entry.value as Map<String, dynamic>;
                                    final monto = info['monto'];
                                    final last4 = info['last4'];
                                    String metodoTexto =
                                        '$metodo: \$${monto.toStringAsFixed(2)}';
                                    if (last4 != null &&
                                        last4.toString().isNotEmpty) {
                                      metodoTexto += ' (****$last4)';
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        metodoTexto,
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.grey[700]),
                                      ),
                                    );
                                  }).toList(),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fecha: ${i.fecha.toLocal().toString().split('.')[0]}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildGradientSquareButton(
              icon: Icons.file_download_outlined,
              onTap: _exportCsv,
              tooltip: 'Exportar Ingresos'),
          const SizedBox(height: 12),
          _buildGradientSquareButton(
              icon: Icons.add,
              onTap: _showAddIngresoDialog,
              tooltip: 'Agregar Ingreso'),
        ],
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
                label: "Cursos",
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

// Botón cuadrado con gradiente (idéntico al usado en Gastos)
Widget _buildGradientSquareButton({
  required IconData icon,
  required VoidCallback onTap,
  String? tooltip,
}) {
  final start = const Color(0xFFF26AB6);
  final end = const Color(0xFFAA57EC);
  final borderRadius = BorderRadius.circular(15);
  final btn = Material(
    color: Colors.transparent,
    elevation: 5,
    shadowColor: Colors.grey.withOpacity(0.5),
    shape: RoundedRectangleBorder(borderRadius: borderRadius),
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [start, end],
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
