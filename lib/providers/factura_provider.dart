import 'package:flutter/material.dart';
import '../models/factura.dart';
import '../models/detalle_factura.dart';
import '../db/db_helper.dart';

class FacturaProvider with ChangeNotifier {
  List<Factura> _facturas = [];

  List<Factura> get facturas => _facturas;

  Future<void> cargarFacturas() async {
    _facturas = await DBHelper.obtenerFacturas();
    notifyListeners();
  }

  Future<int> registrarFactura(Factura factura, List<DetalleFactura> detalles) async {
    final id = await DBHelper.insertarFactura(factura);
    for (var d in detalles) {
      d.facturaId = id;
    }
    await DBHelper.insertarDetallesFactura(detalles);
    await cargarFacturas(); // actualiza la lista
    return id;
  }
}
