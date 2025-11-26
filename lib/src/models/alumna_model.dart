class Alumna {
  String nombre;
  String servicio;
  double anticipo;
  String metodoPago;
  String digitos;
  bool? llego;
  double descuento;
  String razonDescuento;

  Alumna({
    required this.nombre,
    required this.servicio,
    required this.anticipo,
    this.metodoPago = '',
    this.digitos = '',
    this.llego,
    this.descuento = 0.0,
    this.razonDescuento = '',
  });

  factory Alumna.fromJson(Map<String, dynamic> json) => Alumna(
        nombre: json['nombre'],
        servicio: json['servicio'],
        anticipo: (json['anticipo'] as num).toDouble(),
        metodoPago: json['metodoPago'] ?? '',
        digitos: json['digitos'] ?? '',
        llego: json['llego'],
        descuento: (json['descuento'] as num?)?.toDouble() ?? 0.0,
        razonDescuento: json['razonDescuento'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'servicio': servicio,
        'anticipo': anticipo,
        'metodoPago': metodoPago,
        'digitos': digitos,
        'llego': llego,
        'descuento': descuento,
        'razonDescuento': razonDescuento,
      };
}
