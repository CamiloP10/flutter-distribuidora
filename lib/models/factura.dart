class Factura {
  final int? id;
  final int? clienteId;
  final DateTime fecha;
  final double total;
  final double pagado;
  final double saldoPendiente; // <- nuevo campo
  final String tipoPago;
  final String estadoPago;     // <- nuevo campo
  final String informacion;

  Factura({
    this.id,
    this.clienteId,
    required this.fecha,
    required this.total,
    required this.pagado,
    required this.saldoPendiente,
    required this.tipoPago,
    required this.estadoPago,
    required this.informacion,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'clienteId': clienteId,
      'fecha': fecha.toIso8601String(),
      'total': total,
      'pagado': pagado,
      'saldoPendiente': saldoPendiente,
      'tipoPago': tipoPago,
      'estadoPago': estadoPago,
      'informacion': informacion,
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
      fecha: DateTime.parse(map['fecha']),
      total: map['total'],
      pagado: map['pagado'],
      saldoPendiente: map['saldoPendiente'],
      tipoPago: map['tipoPago'],
      estadoPago: map['estadoPago'],
      informacion: map['informacion'] ?? '',
    );
  }
}



