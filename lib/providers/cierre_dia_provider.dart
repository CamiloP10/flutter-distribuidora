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

    // Buscar abonos realizados en el día seleccionado, aunque sean de facturas anteriores
    totalAbonosDelDia = 0;

    for (var factura in facturasDelDia) {
      final info = (factura.informacion ?? '').toLowerCase();

      // Buscar todos los abonos con fechas
      final matches = RegExp(r'abono \$?([\d,\.]+) el (\d{4}-\d{2}-\d{2})').allMatches(info);

      for (var match in matches) {
        final montoTexto = match.group(1)!.replaceAll('.', '').replaceAll(',', '');
        final fechaAbono = match.group(2)!;

        if (fechaAbono == fechaStr) {
          final monto = double.tryParse(montoTexto) ?? 0;
          totalAbonosDelDia += monto;
        }
      }
    }

    totalRecaudo = totalPagado; // por ahora igual (sin separar efectivo/transf)

    isLoading = false;
    notifyListeners();
  }
}