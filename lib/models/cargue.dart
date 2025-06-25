// models/cargue.dart
class Cargue {
  final int id;
  final String nombreRepartidor;
  final DateTime fecha;
  final List<int> facturaIds; // IDs de las facturas asignadas

  Cargue({
    required this.id,
    required this.nombreRepartidor,
    required this.fecha,
    required this.facturaIds,
  });

// Métodos de conversión para SQLite si lo deseas almacenar
}
