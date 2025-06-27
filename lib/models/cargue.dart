class Cargue {
  final int id;
  final String vehiculoAsignado;
  final DateTime fecha;
  final List<int> facturaIds; // IDs de las facturas asignadas
  final String conductor;
  final String observaciones;

  Cargue({
    required this.id,
    required this.vehiculoAsignado,
    required this.fecha,
    required this.facturaIds,
    required this.conductor,
    required this.observaciones,
  });

  //metodo necesario para modificar partes del objeto (como añadir factura)
  Cargue copyWith({
    int? id,
    String? vehiculoAsignado,
    DateTime? fecha,
    List<int>? facturaIds,
    String? conductor,
    String? observaciones,
  }) {
    return Cargue(
      id: id ?? this.id,
      vehiculoAsignado: vehiculoAsignado ?? this.vehiculoAsignado,
      fecha: fecha ?? this.fecha,
      facturaIds: facturaIds ?? this.facturaIds,
      conductor: conductor ?? this.conductor,
      observaciones: observaciones ?? this.observaciones,
    );
  }

  //Convierte desde un Map (para obtener desde SQLite)
  factory Cargue.fromMap(Map<String, dynamic> map) {
    return Cargue(
      id: map['id'],
      vehiculoAsignado: map['vehiculoAsignado'],
      fecha: DateTime.parse(map['fecha']),
      facturaIds: map['facturaIds']
          .toString()
          .split(',')
          .where((id) => id.trim().isNotEmpty)
          .map((id) => int.parse(id))
          .toList(),
      conductor: map['conductor'] ?? '',
      observaciones: map['observaciones'] ?? '',
    );
  }

  //Convierte a Map para guardar en SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehiculoAsignado': vehiculoAsignado,
      'fecha': fecha.toIso8601String(),
      'facturaIds': facturaIds.join(','),
      'conductor': conductor,
      'observaciones': observaciones,
    };
  }
}
