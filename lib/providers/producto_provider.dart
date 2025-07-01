import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/producto.dart';

class ProductoProvider with ChangeNotifier {
  List<Producto> _productos = [];

  List<Producto> get productos => _productos;

  Future<void> cargarProductos() async {
    _productos = await DBHelper.obtenerProductos();
    notifyListeners();
  }

  Future<void> agregarProducto(Producto producto) async {
    await DBHelper.insertarProducto(producto);
    await cargarProductos(); // recargar lista luego de agregar
  }

  Future<void> actualizarProducto(Producto producto) async {
    await DBHelper.actualizarProducto(producto);
    await cargarProductos(); // para recargar la lista en pantalla
  }
//  agregar editarProducto, eliminarProducto, etc.
}