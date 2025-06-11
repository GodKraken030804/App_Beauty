class Alumna {
  final String nombre;
  final String servicio;
  final double anticipo;
  bool llego; // nueva propiedad

  Alumna({
    required this.nombre,
    required this.servicio,
    required this.anticipo,
    this.llego = false,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'servicio': servicio,
        'anticipo': anticipo,
        'llego': llego,
      };

  factory Alumna.fromJson(Map<String, dynamic> json) => Alumna(
        nombre: json['nombre'],
        servicio: json['servicio'],
        anticipo: (json['anticipo'] as num).toDouble(),
        llego: json['llego'] ?? false,
      );
}
