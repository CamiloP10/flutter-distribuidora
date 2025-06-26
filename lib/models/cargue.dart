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
// Métodos de conversión para SQLite
}