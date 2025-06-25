import 'package:flutter/material.dart';
import '../models/cargue.dart';

class CargueProvider extends ChangeNotifier {
  final List<Cargue> _cargues = [];

  List<Cargue> get cargues => _cargues;

  void agregarCargue(Cargue cargue) {
    _cargues.add(cargue);
    notifyListeners();
  }
}
