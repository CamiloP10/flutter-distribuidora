import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/cliente.dart';

class ClienteProvider with ChangeNotifier {
  List<Cliente> _clientes = [];

  List<Cliente> get clientes => _clientes;

  Future<void> cargarClientes() async {
    _clientes = await DBHelper.obtenerClientes();
    notifyListeners();
  }

  Future<void> agregarCliente(Cliente cliente) async {
    await DBHelper.insertarCliente(cliente);
    await cargarClientes(); // Vuelve a cargar la lista desde la DB
  }
  //añadir mas funciones para eliminar, buscar
}
