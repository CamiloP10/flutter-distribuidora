import 'package:flutter/material.dart';
import '../models/factura.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/detalle_factura.dart';
import '../db/db_helper.dart';
import '../models/cargue.dart';


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

  List<DetalleFactura> getAllDetalles() =>
      _detallesPorFactura.values.expand((d) => d).toList();

  List<Cargue> _cargues = [];
  List<Cargue> get cargues => _cargues;

  Future<void> cargarCargues() async {
    _cargues = await DBHelper.obtenerCargues();
    notifyListeners();
  }


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

  Future<void> actualizarCargue(Cargue nuevoCargue) async {
    await DBHelper.actualizarCargue(nuevoCargue);
    await cargarCargues(); // O actualiza solo este cargue si prefieres
  }

  void limpiar() {
    _facturas.clear();
    _clientes.clear();
    _productos.clear();
    _detallesPorFactura.clear();
    notifyListeners();
  }
}