class AsignacionModel {
  final int id;
  final int idCurso;
  final int idEncargado;
  final String excel;

  AsignacionModel({
    required this.id,
    required this.idCurso,
    required this.idEncargado,
    required this.excel,
  });

  factory AsignacionModel.fromJson(Map<String, dynamic> json) {
    return AsignacionModel(
      id: json['id'],
      idCurso: json['id_curso'],
      idEncargado: json['id_encargado'],
      excel: json['excel'],
    );
  }
}
