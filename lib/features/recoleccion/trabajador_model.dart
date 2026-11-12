class TrabajadorModel {
  final String? id;
  final String nombre;
  final String fincaId;
  final String fincaNombre;
  final DateTime creadoEn;

  TrabajadorModel({
    this.id,
    required this.nombre,
    required this.fincaId,
    required this.fincaNombre,
    required this.creadoEn,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'fincaId': fincaId,
        'fincaNombre': fincaNombre,
        'creadoEn': creadoEn.toIso8601String(),
      };

  factory TrabajadorModel.fromMap(Map<String, dynamic> map, String id) =>
      TrabajadorModel(
        id: id,
        nombre: map['nombre'] ?? '',
        fincaId: map['fincaId'] ?? '',
        fincaNombre: map['fincaNombre'] ?? '',
        creadoEn:
            DateTime.tryParse(map['creadoEn'] ?? '') ?? DateTime.now(),
      );
}