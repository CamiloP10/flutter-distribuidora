import 'dart:convert';

class Liquidacion {
  int? id;
  String fecha;
  double totalEfectivo;
  double totalNequi;
  double totalCreditosNuevos;
  double totalCreditosAntiguos;
  double totalDevoluciones;
  Map<String, int> desgloseBilletes; // Usamos un Map para el JSON
  double totalFinal;
  String observaciones;

  Liquidacion({
    this.id,
    required this.fecha,
    required this.totalEfectivo,
    required this.totalNequi,
    required this.totalCreditosNuevos,
    required this.totalCreditosAntiguos,
    required this.totalDevoluciones,
    required this.desgloseBilletes,
    required this.totalFinal,
    this.observaciones = '',
  });

  // Convertir a Map para insertar en SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha,
      'totalEfectivo': totalEfectivo,
      'totalNequi': totalNequi,
      'totalCreditosNuevos': totalCreditosNuevos,
      'totalCreditosAntiguos': totalCreditosAntiguos,
      'totalDevoluciones': totalDevoluciones,
      'desgloseBilletes': jsonEncode(desgloseBilletes), // Convertimos el mapa a String JSON
      'totalFinal': totalFinal,
      'observaciones': observaciones,
    };
  }

  // Crear desde Map (cuando leemos de la DB)
  factory Liquidacion.fromMap(Map<String, dynamic> map) {
    return Liquidacion(
      id: map['id'],
      fecha: map['fecha'],
      totalEfectivo: map['totalEfectivo'],
      totalNequi: map['totalNequi'],
      totalCreditosNuevos: map['totalCreditosNuevos'],
      totalCreditosAntiguos: map['totalCreditosAntiguos'],
      totalDevoluciones: map['totalDevoluciones'],
      desgloseBilletes: Map<String, int>.from(jsonDecode(map['desgloseBilletes'])),
      totalFinal: map['totalFinal'],
      observaciones: map['observaciones'] ?? '',
    );
  }
}