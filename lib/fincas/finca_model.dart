class FincaModel {
  final String? id;
  final String nombre;
  final String departamento;
  final String municipio;
  final String vereda;
  final double altura;
  final double hectareas;
  final DateTime creadaEn;

  FincaModel({
    this.id,
    required this.nombre,
    required this.departamento,
    required this.municipio,
    required this.vereda,
    required this.altura,
    required this.hectareas,
    required this.creadaEn,
  });

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'departamento': departamento,
    'municipio': municipio,
    'vereda': vereda,
    'altura': altura,
    'hectareas': hectareas,
    'creadaEn': creadaEn.toIso8601String(),
  };

  factory FincaModel.fromMap(Map<String, dynamic> map, String id) => FincaModel(
    id: id,
    nombre: map['nombre'] ?? '',
    departamento: map['departamento'] ?? '',
    municipio: map['municipio'] ?? '',
    vereda: map['vereda'] ?? '',
    altura: (map['altura'] ?? 0).toDouble(),
    hectareas: (map['hectareas'] ?? 0).toDouble(),
    creadaEn: DateTime.tryParse(map['creadaEn'] ?? '') ?? DateTime.now(),
  );
}