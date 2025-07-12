import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/factura.dart';

class CierreDiaProvider extends ChangeNotifier {
  DateTime fechaSeleccionada = DateTime.now();
  List<Factura> facturasDelDia = [];
  List<Map<String, dynamic>> abonosDetallados = []; //cada item tendrá: facturaId, cliente, monto
  Map<int, String> nombresClientes = {};

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

    nombresClientes = {}; // limpiar mapa

    final todosClientes = await DBHelper.obtenerClientes();
    for (final c in todosClientes) {
      nombresClientes[c.id!] = c.nombre;
    }

    // 2. Obtener todos los abonos realizados en esa fecha
    final abonosDelDia = await DBHelper.obtenerAbonosPorFecha(fechaSeleccionada);

    // 3. Excluir abonos a facturas creadas hoy (para evitar doble conteo)
    final facturaIdsHoy = facturasDelDia.map((f) => f.id).toSet();

    final abonosFacturasAnteriores = abonosDelDia
        .where((ab) => !facturaIdsHoy.contains(ab.facturaId))
        .toList();

    // Reiniciar valores
    totalAbonosDelDia = 0;
    abonosDetallados = [];

// Iterar sobre abonos válidos
    for (final ab in abonosFacturasAnteriores) {
      try {
        final factura = await DBHelper.obtenerFacturaPorId(ab.facturaId);

        if (factura.clienteId == null) {
          print('La factura ${factura.id} no tiene cliente asignado');
          continue;
        }

        if (factura.clienteId == null) {
          print('La factura ${factura.id} no tiene cliente asignado');
          continue;
        }

        final cliente = await DBHelper.obtenerClientePorId(factura.clienteId!);

        abonosDetallados.add({
          'facturaId': ab.facturaId,
          'cliente': cliente.nombre, // ✅ ahora sí está definida la variable
          'monto': ab.monto,
        });

        totalAbonosDelDia += ab.monto;
      } catch (e) {
        print('❌ Error al obtener datos de abono: $e');
      }
    }

    // 4. Recaudo total = pagado por facturas del día (puedes separar efectivo/transferencia luego)
    totalRecaudo = totalPagado;

    isLoading = false;
    notifyListeners();
  }
}