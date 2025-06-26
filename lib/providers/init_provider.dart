import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class InitProvider with ChangeNotifier {
  bool _isLoading = true;
  bool _hasInitialized = false;
  bool get isLoading => _isLoading;

  Future<void> inicializarTodo() async {
    if (_hasInitialized) return; // Protege contra múltiples llamadas en cel
    _hasInitialized = true;

    _isLoading = true;
    notifyListeners();

    try {
      await DBHelper.initDb();
      await DBHelper.importarInventarioDesdeCSV();
      await DBHelper.importarClientesDesdeCSV();
    } catch (e) {
      print('Error durante inicialización: $e');
    }
    _isLoading = false;
    notifyListeners();
  }
}