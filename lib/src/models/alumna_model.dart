class Alumna {
  final String nombre;
  final String servicio;
  final double anticipo;
  final String metodoPago;
  final String digitos;
  final bool? llego;
  final double descuento;
  final String razonDescuento;
  final double pagoRestante;
  final String descripcion;

  Alumna({
    required this.nombre,
    required this.servicio,
    required this.anticipo,
    required this.metodoPago,
    required this.digitos,
    this.llego,
    required this.descuento,
    required this.razonDescuento,
    required this.pagoRestante,
    required this.descripcion,
  });

  Alumna copyWith({
    String? nombre,
    String? servicio,
    double? anticipo,
    String? metodoPago,
    String? digitos,
    bool? llego,
    double? descuento,
    String? razonDescuento,
    double? pagoRestante,
    String? descripcion,
  }) {
    return Alumna(
      nombre: nombre ?? this.nombre,
      servicio: servicio ?? this.servicio,
      anticipo: anticipo ?? this.anticipo,
      metodoPago: metodoPago ?? this.metodoPago,
      digitos: digitos ?? this.digitos,
      llego: llego ?? this.llego,
      descuento: descuento ?? this.descuento,
      razonDescuento: razonDescuento ?? this.razonDescuento,
      pagoRestante: pagoRestante ?? this.pagoRestante,
      descripcion: descripcion ?? this.descripcion,
    );
  }

  factory Alumna.fromJson(Map<String, dynamic> json) {
    return Alumna(
      nombre: json['nombre'] as String,
      servicio: json['servicio'] as String,
      anticipo: (json['anticipo'] as num).toDouble(),
      metodoPago: json['metodoPago'] as String,
      digitos: json['digitos'] as String,
      llego: json['llego'] as bool?,
      descuento: (json['descuento'] as num? ?? 0.0).toDouble(),
      razonDescuento: json['razonDescuento'] as String? ?? '',
      pagoRestante: (json['pagoRestante'] as num? ?? 0.0).toDouble(),
      descripcion: json['descripcion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'servicio': servicio,
      'anticipo': anticipo,
      'metodoPago': metodoPago,
      'digitos': digitos,
      'llego': llego,
      'descuento': descuento,
      'razonDescuento': razonDescuento,
      'pagoRestante': pagoRestante,
      'descripcion': descripcion,
    };
  }
}
