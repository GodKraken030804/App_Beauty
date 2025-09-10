class Alumna {
  String nombre;
  String servicio;
  double anticipo;
  String metodoPago;
  String digitos;
  bool? llego;

  Alumna({
    required this.nombre,
    required this.servicio,
    required this.anticipo,
    this.metodoPago = '',
    this.digitos = '',
    this.llego,
  });

  

  factory Alumna.fromJson(Map<String, dynamic> json) => Alumna(
        nombre: json['nombre'],
        servicio: json['servicio'],
        anticipo: (json['anticipo'] as num).toDouble(),
        metodoPago: json['metodoPago'] ?? '',
        digitos: json['digitos'] ?? '',
        llego: json['llego'],
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'servicio': servicio,
        'anticipo': anticipo,
        'metodoPago': metodoPago,
        'digitos': digitos,
        'llego': llego,
      };

      
}