import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/factura.dart';

class CierreDiaProvider extends ChangeNotifier {
  DateTime fechaSeleccionada = DateTime.now();
  List<Factura> facturasDelDia = [];

  int totalFacturas = 0;
  double totalPagado = 0;
  double totalCredito = 0;
  double totalRecaudo = 0;
  double totalVentas = 0;
  double totalAbonosDelDia = 0;

  bool isLoading = true;

  void cambiarFecha(DateTime nuevaFecha) {
    fechaSeleccionada = nuevaFecha;
    cargarResumenDelDia();
  }

  Future<void> cargarResumenDelDia() async {
    isLoading = true;
    notifyListeners();

    final db = await DBHelper.initDb();
    final fechaStr = fechaSeleccionada.toIso8601String().substring(0, 10); // YYYY-MM-DD

    // 1. Obtener facturas creadas en la fecha seleccionada
    final data = await db.rawQuery('''
    SELECT * FROM factura
    WHERE DATE(fecha) = ?
  ''', [fechaStr]);

    facturasDelDia = data.map((e) => Factura.fromMap(e)).toList();

    totalFacturas = facturasDelDia.length;
    totalPagado = 0;
    totalCredito = 0;
    totalVentas = 0;

    for (var f in facturasDelDia) {
      totalPagado += f.pagado ?? 0;
      totalVentas += f.total ?? 0;

      if ((f.estadoPago ?? '').toLowerCase() == 'crédito') {
        totalCredito += f.saldoPendiente ?? 0;
      }
    }

    // 2. Obtener todos los abonos realizados en esa fecha
    final abonosDelDia = await DBHelper.obtenerAbonosPorFecha(fechaSeleccionada);

    // 3. Excluir abonos a facturas creadas hoy (para evitar doble conteo)
    final facturaIdsHoy = facturasDelDia.map((f) => f.id).toSet();

    final abonosFacturasAnteriores = abonosDelDia
        .where((ab) => !facturaIdsHoy.contains(ab.facturaId))
        .toList();

    totalAbonosDelDia = abonosFacturasAnteriores.fold(0.0, (sum, a) => sum + a.monto);

    // 4. Recaudo total = pagado por facturas del día (puedes separar efectivo/transferencia luego)
    totalRecaudo = totalPagado;

    isLoading = false;
    notifyListeners();
  }
}