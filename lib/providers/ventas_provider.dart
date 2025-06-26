import 'package:flutter/material.dart';
import '../models/factura.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/detalle_factura.dart';
import '../db/db_helper.dart';

class VentasProvider with ChangeNotifier {
  List<Factura> _facturas = [];
  Map<int, Cliente> _clientes = {};
  Map<int, Producto> _productos = {};
  Map<int, List<DetalleFactura>> _detallesPorFactura = {};

  bool _cargando = false;

  bool get cargando => _cargando;
  List<Factura> get facturas => _facturas;
  Cliente? getCliente(int? id) => _clientes[id];
  Producto? getProducto(int? id) => _productos[id];
  List<DetalleFactura> getDetalles(int facturaId) => _detallesPorFactura[facturaId] ?? [];
  Map<int, Producto> get productosMap => _productos;

    //prueba productos en pdf
  List<DetalleFactura> getAllDetalles() =>
      _detallesPorFactura.values.expand((d) => d).toList();


  Future<void> cargarDatos() async {
    _cargando = true;
    notifyListeners();

    _facturas = await DBHelper.obtenerFacturas();
    final clientes = await DBHelper.obtenerClientes();
    final productos = await DBHelper.obtenerProductos();

    _clientes = {for (var c in clientes) c.id!: c};
    _productos = {for (var p in productos) p.id!: p};

    _detallesPorFactura = {};
    for (var factura in _facturas) {
      final detalles = await DBHelper.obtenerDetallesFactura(factura.id!);
      _detallesPorFactura[factura.id!] = detalles;
    }

    _cargando = false;
    notifyListeners();
  }

  void limpiar() {
    _facturas.clear();
    _clientes.clear();
    _productos.clear();
    _detallesPorFactura.clear();
    notifyListeners();
  }
}
