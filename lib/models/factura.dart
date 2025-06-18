class Factura {
  final int? id;
  final int clienteId;
  final DateTime fecha;
  final double total;

  Factura({
    this.id,
    required this.clienteId,
    required this.fecha,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'clienteId': clienteId,
      'fecha': fecha.toIso8601String(), // <- convertir DateTime a String
      'total': total,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Factura.fromMap(Map<String, dynamic> map) {
    return Factura(
      id: map['id'],
      clienteId: map['clienteId'],
      fecha: DateTime.parse(map['fecha']), // <- convertir String a DateTime
      total: map['total'],
    );
  }
}


