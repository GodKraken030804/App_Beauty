// ... (importaciones sin cambios)
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:another_flushbar/flushbar.dart';

class AgregarProductoView extends StatefulWidget {
  const AgregarProductoView({super.key});

  @override
  State<AgregarProductoView> createState() => _AgregarProductoViewState();
}

class _AgregarProductoViewState extends State<AgregarProductoView> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _precioController = TextEditingController();
  Uint8List? _imagenBytes;
  String? _imagenNombre;

  final List<Color> gradientColors = const [Color(0xFFF26AB6), Color(0xFFAA57EC)];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imagenBytes = bytes;
        _imagenNombre = picked.name;
      });
    }
  }

  Future<void> _guardarProducto() async {
    if (_formKey.currentState!.validate()) {
      try {
        final uri = Uri.parse('http://3.235.82.25:3000/registrar-producto');
        final request = http.MultipartRequest('POST', uri);

        request.fields['nombre'] = _nombreController.text.trim();
        request.fields['cantidad'] = _cantidadController.text.trim();
        request.fields['precio'] = _precioController.text.trim();

        if (_imagenBytes != null && _imagenNombre != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'imagen',
              _imagenBytes!,
              filename: _imagenNombre,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }

        final response = await request.send();
        final responseBody = await http.Response.fromStream(response);

        if (response.statusCode == 200) {
          _mostrarAlerta("Producto registrado exitosamente", success: true);
          limpiarFormulario(); // ✅ Limpiar campos al finalizar exitosamente
        } else {
          _mostrarAlerta("Error al registrar producto: ${responseBody.body}", success: false);
        }
      } catch (e) {
        _mostrarAlerta("Error de red: $e", success: false);
      }
    }
  }

  void limpiarFormulario() {
    setState(() {
      _nombreController.clear();
      _cantidadController.clear();
      _precioController.clear();
      _imagenBytes = null;
      _imagenNombre = null;
    });
  }

  void _mostrarAlerta(String mensaje, {required bool success}) {
    Flushbar(
      message: mensaje,
      backgroundColor: success ? const Color(0xFFF26AB6) : Colors.redAccent,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      icon: Icon(
        success ? Icons.check_circle : Icons.error,
        color: Colors.white,
        size: 28,
      ),
      duration: const Duration(seconds: 3),
    ).show(context);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
    
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Image.asset(
                'assets/images/Logo.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(_nombreController, 'Nombre del producto'),
                    const SizedBox(height: 15),
                    _buildTextField(_cantidadController, 'Cantidad', isNumber: true),
                    const SizedBox(height: 15),
                    _buildTextField(_precioController, 'Precio', isDecimal: true),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: _imagenBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.memory(_imagenBytes!, fit: BoxFit.cover),
                              )
                            : const Center(
                                child: Text('Selecciona una imagen'),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    InkWell(
                      onTap: _guardarProducto,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Guardar Producto',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, bool isDecimal = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : isNumber
              ? TextInputType.number
              : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Campo requerido' : null,
    );
  }
}
