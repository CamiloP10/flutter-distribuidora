import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/producto.dart';
import '../models/cliente.dart';
import '../models/factura.dart';
import '../models/detalle_factura.dart';

import 'dart:convert';

class DBHelper {
  static Database? _db;

  // Inicializar la base de datos
  static Future<Database> initDb() async {
    if (_db != null) return _db!;

    String path = join(await getDatabasesPath(), 'inventario.db');
    //await deleteDatabase(path); // <--- DESCOMENTAR para reiniciar la DB

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );

    return _db!;
  }

  // Crear las tablas
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cliente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        telefono TEXT,
        informacion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE producto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo text,
        nombre TEXT,
        presentacion TEXT,
        cantidad INTEGER,
        precio REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE factura (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clienteId INTEGER,
        fecha TEXT,
        total REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE detalle_factura (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        facturaId INTEGER,
        productoId INTEGER,
        cantidad INTEGER,
        precioUnitario REAL
      )
    ''');
  }

  // FUNCIONES PARA PRODUCTOS
  static Future<int> insertarProducto(Producto producto) async {
    final db = await initDb();
    return await db.insert('producto', producto.toMap());
  }

  static Future<List<Producto>> obtenerProductos() async {
    final db = await initDb();
    final List<Map<String, dynamic>> maps = await db.query('producto');
    return List.generate(maps.length, (i) => Producto.fromMap(maps[i]));
  }

  // FUNCIONES PARA CLIENTES
  static Future<int> insertarCliente(Cliente cliente) async {
    final db = await initDb();
    return await db.insert('cliente', cliente.toMap());
  }

  static Future<List<Cliente>> obtenerClientes() async {
    final db = await initDb();
    final List<Map<String, dynamic>> maps = await db.query('cliente');
    return List.generate(maps.length, (i) => Cliente.fromMap(maps[i]));
  }

  // FACTURAS
  static Future<int> insertarFactura(Factura factura) async {
    final db = await initDb();
    return await db.insert('factura', factura.toMap());
  }

  static Future<List<Factura>> obtenerFacturas() async {
    final db = await initDb();
    final List<Map<String, dynamic>> maps = await db.query('factura');
    return List.generate(maps.length, (i) => Factura.fromMap(maps[i]));
  }

  // DETALLES DE FACTURA
  static Future<void> insertarDetallesFactura(List<DetalleFactura> detalles) async {
    final db = await initDb();
    for (var detalle in detalles) {
      await db.insert('detalle_factura', detalle.toMap());
    }
  }

  // IMPORTAR INVENTARIO DESDE CSV
  static Future<void> importarInventarioDesdeCSV() async {
    final prefs = await SharedPreferences.getInstance();
    final yaImportado = prefs.getBool('inventario_cargado') ?? false;

    //forzar recarga
    //await prefs.setBool('inventario_cargado', false); // Forzar que se recargue

    // comentar el if  cuando se esta forzando a recargar onCreate
    if (yaImportado) {
      print("Inventario ya cargado previamente. No se importa de nuevo.");
      return;
    }

      try {
        final rawData = await rootBundle.loadString('assets/Inventario.csv');
        //final rows = const CsvToListConverter().convert(rawData);
        final rows = const CsvToListConverter(fieldDelimiter: ';').convert(rawData);

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];

          final producto = Producto(
            codigo: row[0].toString(),
            nombre: row[1].toString(),
            presentacion: row[2].toString(),
            cantidad: int.tryParse(row[3].toString()) ?? 0,
            precio: double.tryParse(row[4].toString()) ?? 0.0,
          );

          await insertarProducto(producto);
        }

        await prefs.setBool('inventario_cargado', true);
        print('Inventario importado correctamente desde CSV');

      } catch (e) {
        print('Error al importar el CSV: $e');
      }
    }

  // IMPORTAR clientes DESDE CSV
  static Future<void> importarClientesDesdeCSV() async {
    final prefs = await SharedPreferences.getInstance();
    final yaImportado = prefs.getBool('clientes_cargados') ?? false;

    // Forzar recarga:
    //await prefs.setBool('clientes_cargados', false); // Forzar que se recargue

    // comentar el if  cuando se esta forzando a recargar onCreate
    if (yaImportado) {
      print("Clientes ya cargados previamente. No se importa de nuevo.");
      return;
    }

    try {
      final data = await rootBundle.loadString('assets/clientes.csv');
      final rows = const CsvToListConverter(fieldDelimiter: ';').convert(data);

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        final cliente = Cliente(
          nombre: row[0].toString(),
          telefono: row[1].toString(),
          informacion: row[2].toString(),
        );

        await insertarCliente(cliente);
      }

      await prefs.setBool('clientes_cargados', true);
      print('Clientes importados correctamente desde CSV');
    } catch (e) {
      print('Error al importar clientes desde CSV: $e');
    }
  }
}




