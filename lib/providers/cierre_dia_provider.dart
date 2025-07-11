import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/factura.dart';

class CierreDiaProvider extends ChangeNotifier {
  List<Factura> facturasDelDia = [];

  int totalFacturas = 0;
  double totalEfectivo = 0;
  double totalTransferencia = 0;
  double totalCredito = 0;
  double totalRecaudado = 0;

  bool isLoading = true;

  Future<void> cargarResumenDelDia() async {
    final db = await DBHelper.initDb();
    final hoy = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

    final data = await db.rawQuery('''
      SELECT * FROM factura
      WHERE DATE(fecha) = DATE('now')
    ''');

    facturasDelDia = data.map((f) => Factura.fromMap(f)).toList();

    totalFacturas = facturasDelDia.length;
    totalEfectivo = 0;
    totalTransferencia = 0;
    totalCredito = 0;
    totalRecaudado = 0;

    for (var factura in facturasDelDia) {
      final tipoPago = (factura.tipoPago ?? '').toLowerCase();
      final pagado = factura.pagado ?? 0;
      final saldo = factura.saldoPendiente ?? 0;

      if (tipoPago == 'efectivo') {
        totalEfectivo += pagado;
      } else if (tipoPago == 'transferencia') {
        totalTransferencia += pagado;
      }

      if ((factura.estadoPago ?? '').toLowerCase() == 'crédito') {
        totalCredito += saldo;
      }

      totalRecaudado += pagado;
    }

    isLoading = false;
    notifyListeners();
  }
}