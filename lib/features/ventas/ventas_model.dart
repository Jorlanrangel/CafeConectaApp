class ItemVenta {
  final String tipoCafe;
  final double latas;
  final double precioPorLata;

  ItemVenta({
    required this.tipoCafe,
    required this.latas,
    required this.precioPorLata,
  });

  double get subtotal => latas * precioPorLata;

  Map<String, dynamic> toMap() => {
        'tipoCafe': tipoCafe,
        'latas': latas,
        'precioPorLata': precioPorLata,
        'subtotal': subtotal,
      };

  factory ItemVenta.fromMap(Map<String, dynamic> map) => ItemVenta(
        tipoCafe: map['tipoCafe'] ?? '',
        latas: (map['latas'] ?? 0).toDouble(),
        precioPorLata: (map['precioPorLata'] ?? 0).toDouble(),
      );
}

class VentaModel {
  final String? id;
  final String fincaId;
  final String fincaNombre;
  final String vendedor;
  final List<ItemVenta> items;
  final double totalLatas;
  final double totalPagar;
  final DateTime fecha;

  VentaModel({
    this.id,
    required this.fincaId,
    required this.fincaNombre,
    required this.vendedor,
    required this.items,
    required this.totalLatas,
    required this.totalPagar,
    required this.fecha,
  });

  Map<String, dynamic> toMap() => {
        'fincaId': fincaId,
        'fincaNombre': fincaNombre,
        'vendedor': vendedor,
        'items': items.map((i) => i.toMap()).toList(),
        'totalLatas': totalLatas,
        'totalPagar': totalPagar,
        'fecha': fecha.toIso8601String(),
      };

  factory VentaModel.fromMap(Map<String, dynamic> map, String id) => VentaModel(
        id: id,
        fincaId: map['fincaId'] ?? '',
        fincaNombre: map['fincaNombre'] ?? '',
        vendedor: map['vendedor'] ?? '',
        items: (map['items'] as List<dynamic>? ?? [])
            .map((i) => ItemVenta.fromMap(i as Map<String, dynamic>))
            .toList(),
        totalLatas: (map['totalLatas'] ?? 0).toDouble(),
        totalPagar: (map['totalPagar'] ?? 0).toDouble(),
        fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      );
}