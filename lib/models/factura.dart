//documento general. Representa la cabecera del documento: fecha, total, cliente,
class Factura {
  final int? id;
  final int? clienteId;
  final DateTime fecha;
  final double total;
  final double pagado;
  final double saldoPendiente;
  final String tipoPago;
  final String estadoPago;
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

  Factura copyWith({
    int? id,
    int? clienteId,
    DateTime? fecha,
    double? total,
    double? pagado,
    double? saldoPendiente,
    String? tipoPago,
    String? estadoPago,
    String? informacion,
  }) {
    return Factura(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      fecha: fecha ?? this.fecha,
      total: total ?? this.total,
      pagado: pagado ?? this.pagado,
      saldoPendiente: saldoPendiente ?? this.saldoPendiente,
      tipoPago: tipoPago ?? this.tipoPago,
      estadoPago: estadoPago ?? this.estadoPago,
      informacion: informacion ?? this.informacion,
    );
  }
}
