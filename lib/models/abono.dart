class Abono {
  final int? id;
  final int facturaId;
  final double monto;
  final DateTime fecha;

  Abono({
    this.id,
    required this.facturaId,
    required this.monto,
    required this.fecha,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'facturaId': facturaId,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Abono.fromMap(Map<String, dynamic> map) {
    return Abono(
      id: map['id'],
      facturaId: map['facturaId'],
      monto: map['monto'],
      fecha: DateTime.parse(map['fecha']),
    );
  }
}