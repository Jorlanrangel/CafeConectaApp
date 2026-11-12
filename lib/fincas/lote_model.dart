class LoteModel {
  final String? id;
  final String nombre;
  final double altura;
  final String variedad;
  final String fincaId;
  final DateTime creadoEn;

  LoteModel({
    this.id,
    required this.nombre,
    required this.altura,
    required this.variedad,
    required this.fincaId,
    required this.creadoEn,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'altura': altura,
        'variedad': variedad,
        'fincaId': fincaId,
        'creadoEn': creadoEn.toIso8601String(),
      };

  factory LoteModel.fromMap(Map<String, dynamic> map, String id) => LoteModel(
        id: id,
        nombre: map['nombre'] ?? '',
        altura: (map['altura'] ?? 0).toDouble(),
        variedad: map['variedad'] ?? '',
        fincaId: map['fincaId'] ?? '',
        creadoEn:
            DateTime.tryParse(map['creadoEn'] ?? '') ?? DateTime.now(),
      );
}