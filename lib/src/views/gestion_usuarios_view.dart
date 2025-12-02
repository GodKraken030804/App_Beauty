import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:another_flushbar/flushbar.dart';
import '../services/user_service.dart';
import 'admin_view.dart';
import 'mi_perfil_admin.dart';

class GestionUsuariosView extends StatefulWidget {
  const GestionUsuariosView({super.key});

  @override
  State<GestionUsuariosView> createState() => _GestionUsuariosViewState();
}

class _GestionUsuariosViewState extends State<GestionUsuariosView> {
  final UserService _userService = UserService();
  List<dynamic> _usuarios = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final usuarios = await _userService.getUsuarios();
      setState(() {
        _usuarios = usuarios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarMensaje('Error al cargar usuarios', isError: true);
    }
  }

  void _mostrarMensaje(String mensaje, {bool isError = false}) {
    Flushbar(
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(15),
      backgroundColor: isError ? Colors.red : const Color(0xFFF26AB6),
      flushbarPosition: FlushbarPosition.TOP,
      icon: Icon(
        isError ? Icons.error : Icons.check_circle,
        color: Colors.white,
        size: 28,
      ),
      messageText: Text(
        mensaje,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      duration: const Duration(seconds: 3),
    ).show(context);
  }

  Future<void> _confirmarEliminacion(int id, String nombre) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade400, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Confirmar Eliminación',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            '¿Está seguro que desea eliminar al usuario "$nombre"?\n\nEsta acción no se puede deshacer.',
            style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Colors.red],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Eliminar',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final exitoso = await _userService.eliminarUsuario(id);
      if (exitoso) {
        _mostrarMensaje('Usuario eliminado correctamente');
        _cargarUsuarios();
      } else {
        _mostrarMensaje('Error al eliminar usuario', isError: true);
      }
    }
  }

  void _mostrarFormularioUsuario({Map<String, dynamic>? usuario}) {
    final bool esEdicion = usuario != null;
    final nombreController =
        TextEditingController(text: usuario?['nombre'] ?? '');
    final apellidoController =
        TextEditingController(text: usuario?['apellido'] ?? '');
    final telefonoController =
        TextEditingController(text: usuario?['telefono'] ?? '');
    final gmailController =
        TextEditingController(text: usuario?['gmail'] ?? '');
    final codigoController =
        TextEditingController(text: usuario?['codigo'] ?? '');
    final usuarioController =
        TextEditingController(text: usuario?['usuario'] ?? '');
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header con icono
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      esEdicion ? Icons.edit : Icons.person_add,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    esEdicion ? 'Editar Usuario' : 'Crear Nuevo Usuario',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(nombreController, 'Nombre', Icons.person),
                  const SizedBox(height: 16),
                  _buildTextField(
                      apellidoController, 'Apellido', Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildTextField(telefonoController, 'Teléfono', Icons.phone,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildTextField(gmailController, 'Email', Icons.email,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildTextField(codigoController, 'Código', Icons.badge),
                  const SizedBox(height: 16),
                  _buildTextField(
                      usuarioController, 'Usuario', Icons.account_circle),
                  const SizedBox(height: 16),
                  _buildTextField(
                    passwordController,
                    esEdicion ? 'Contraseña (opcional)' : 'Contraseña',
                    Icons.lock,
                    isPassword: true,
                  ),
                  const SizedBox(height: 28),
                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                                color: Color(0xFFF26AB6), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFF26AB6),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF26AB6).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nombreController.text.isEmpty ||
                                  apellidoController.text.isEmpty ||
                                  gmailController.text.isEmpty ||
                                  usuarioController.text.isEmpty ||
                                  (!esEdicion &&
                                      passwordController.text.isEmpty)) {
                                _mostrarMensaje(
                                    'Por favor complete todos los campos requeridos',
                                    isError: true);
                                return;
                              }

                              bool exitoso;
                              if (esEdicion) {
                                exitoso = await _userService.actualizarUsuario(
                                  id: usuario['id'],
                                  nombre: nombreController.text,
                                  apellido: apellidoController.text,
                                  telefono: telefonoController.text,
                                  gmail: gmailController.text,
                                  codigo: codigoController.text,
                                  usuario: usuarioController.text,
                                  password: passwordController.text.isNotEmpty
                                      ? passwordController.text
                                      : null,
                                );
                              } else {
                                exitoso = await _userService.crearUsuario(
                                  nombre: nombreController.text,
                                  apellido: apellidoController.text,
                                  telefono: telefonoController.text,
                                  gmail: gmailController.text,
                                  codigo: codigoController.text,
                                  usuario: usuarioController.text,
                                  password: passwordController.text,
                                );
                              }

                              if (exitoso) {
                                Navigator.pop(context);
                                _mostrarMensaje(esEdicion
                                    ? 'Usuario actualizado correctamente'
                                    : 'Usuario creado correctamente');
                                _cargarUsuarios();
                              } else {
                                _mostrarMensaje('Error al guardar usuario',
                                    isError: true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              esEdicion ? 'Actualizar' : 'Crear Usuario',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: const Color(0xFF9A9A9A)),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFF26AB6), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarUsuarios,
              child: _usuarios.isEmpty
                  ? Center(
                      child: Text(
                        'No hay usuarios registrados',
                        style: GoogleFonts.poppins(
                            fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _usuarios.length,
                      itemBuilder: (context, index) {
                        final usuario = _usuarios[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF26AB6).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Avatar con gradiente
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFF26AB6),
                                          Color(0xFFAA57EC)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF26AB6)
                                              .withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${usuario['nombre']?[0] ?? ''}${usuario['apellido']?[0] ?? ''}'
                                            .toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Información del usuario
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${usuario['nombre'] ?? ''} ${usuario['apellido'] ?? ''}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color: const Color(0xFF2D3142),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.person,
                                                size: 14,
                                                color: Color(0xFF9A9A9A)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                usuario['usuario'] ?? '',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color:
                                                      const Color(0xFF6B6B6B),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(Icons.email,
                                                size: 14,
                                                color: Color(0xFF9A9A9A)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                usuario['gmail'] ?? '',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color:
                                                      const Color(0xFF6B6B6B),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(Icons.badge,
                                                size: 14,
                                                color: Color(0xFF9A9A9A)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Código: ${usuario['codigo'] ?? ''}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: const Color(0xFF6B6B6B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Botones de acción
                                  Column(
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _mostrarFormularioUsuario(
                                                usuario: usuario),
                                        icon: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFF26AB6),
                                                Color(0xFFAA57EC)
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.edit,
                                              color: Colors.white, size: 20),
                                        ),
                                        tooltip: 'Editar',
                                      ),
                                      IconButton(
                                        onPressed: () => _confirmarEliminacion(
                                          usuario['id'],
                                          '${usuario['nombre']} ${usuario['apellido']}',
                                        ),
                                        icon: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade400,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.delete,
                                              color: Colors.white, size: 20),
                                        ),
                                        tooltip: 'Eliminar',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 65,
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              currentIndex: _currentIndex,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
                setState(() => _currentIndex = index);
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
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFFF26AB6), Color(0xFFAA57EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF26AB6).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _mostrarFormularioUsuario(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.person_add, color: Colors.white, size: 24),
          label: Text(
            'Nuevo Usuario',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
