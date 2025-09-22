import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/factura.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/detalle_factura.dart';
import '../models/cargue.dart';

class VentasProvider with ChangeNotifier {
  List<Factura> _facturas = [];
  Map<int, Cliente> _clientes = {};
  Map<int, Producto> _productos = {};
  Map<int, List<DetalleFactura>> _detallesPorFactura = {};
  List<Cargue> _cargues = [];

  bool _cargando = false;
  bool get cargando => _cargando;

  // 📌 Getters públicos
  List<Factura> get facturas => _facturas;
  List<Cargue> get cargues => _cargues;
  List<Producto> get productos => _productos.values.toList();
  Map<int, Producto> get productosMap => _productos;
  Map<int, Cliente> get clientes => _clientes;

  Cliente? getCliente(int? id) => _clientes[id];

  // ✅ Devuelve los detalles ya cargados en memoria
  List<DetalleFactura> getDetallesFactura(int facturaId) {
    return _detallesPorFactura[facturaId] ?? [];
  }

  // ✅ Cargar detalles desde DB y guardarlos en caché
  Future<List<DetalleFactura>> cargarDetallesFactura(int facturaId) async {
    final detalles = await DBHelper.obtenerDetallesFactura(facturaId);
    _detallesPorFactura[facturaId] = detalles;
    notifyListeners();
    return detalles;
  }

  // ✅ Facturas
  Future<void> cargarFacturas() async {
    _cargando = true;
    notifyListeners();
    _facturas = await DBHelper.obtenerFacturas();
    _cargando = false;
    notifyListeners();
  }

  // ✅ Clientes
  Future<void> cargarClientes() async {
    final clientes = await DBHelper.obtenerClientes();
    _clientes = {for (var c in clientes) c.id!: c};
    notifyListeners();
  }

  // ✅ Productos
  Future<void> cargarProductos() async {
    final productos = await DBHelper.obtenerProductos();
    _productos = {for (var p in productos) p.id!: p};
    notifyListeners();
  }

  // ✅ Cargues
  Future<void> cargarCargues() async {
    _cargues = await DBHelper.obtenerCargues();
    notifyListeners();
  }

  Future<void> actualizarCargue(Cargue nuevoCargue) async {
    await DBHelper.actualizarCargue(nuevoCargue);
    await cargarCargues();
  }

  // ✅ Actualizar factura en DB y memoria
  Future<void> actualizarFactura(Factura factura) async {
    await DBHelper.actualizarFactura(factura);

    final index = _facturas.indexWhere((f) => f.id == factura.id);
    if (index != -1) {
      _facturas[index] = factura;
    }

    notifyListeners();
  }

  // ✅ Limpiar caché (por ejemplo, al cerrar sesión o resetear datos)
  void limpiar() {
    _facturas.clear();
    _clientes.clear();
    _productos.clear();
    _detallesPorFactura.clear();
    _cargues.clear();
    notifyListeners();
  }
}