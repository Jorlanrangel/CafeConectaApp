class CosechaModel {
  final String? id;
  final String fincaId;
  final String fincaNombre;
  final String loteId;
  final String loteNombre;
  final String trabajadorId;
  final String trabajadorNombre;
  final double kilos;
  final DateTime fecha;

  CosechaModel({
    this.id,
    required this.fincaId,
    required this.fincaNombre,
    required this.loteId,
    required this.loteNombre,
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.kilos,
    required this.fecha,
  });

  Map<String, dynamic> toMap() => {
        'fincaId': fincaId,
        'fincaNombre': fincaNombre,
        'loteId': loteId,
        'loteNombre': loteNombre,
        'trabajadorId': trabajadorId,
        'trabajadorNombre': trabajadorNombre,
        'kilos': kilos,
        'fecha': fecha.toIso8601String(),
      };

  factory CosechaModel.fromMap(Map<String, dynamic> map, String id) =>
      CosechaModel(
        id: id,
        fincaId: map['fincaId'] ?? '',
        fincaNombre: map['fincaNombre'] ?? '',
        loteId: map['loteId'] ?? '',
        loteNombre: map['loteNombre'] ?? '',
        trabajadorId: map['trabajadorId'] ?? '',
        trabajadorNombre: map['trabajadorNombre'] ?? '',
        kilos: (map['kilos'] ?? 0).toDouble(),
        fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      );
}