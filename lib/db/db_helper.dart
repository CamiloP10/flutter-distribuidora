import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto.dart';
import '../models/cliente.dart';
import '../models/factura.dart';
import '../models/detalle_factura.dart';
import '../models/cargue.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> initDb() async {
    if (_db != null) return _db!;
    String path = join(await getDatabasesPath(), 'inventario.db');
    _db = await openDatabase(path, version: 1, onCreate: _onCreate);
    return _db!;
  }

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
        codigo TEXT,
        nombre TEXT,
        presentacion TEXT,
        cantidad REAL,
        precio REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE factura (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clienteId INTEGER,
        fecha TEXT,
        total REAL,
        pagado REAL,
        saldoPendiente REAL,
        tipoPago TEXT,
        estadoPago TEXT,
        informacion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE detalle_factura (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        facturaId INTEGER,
        productoId INTEGER,
        cantidad REAL,
        precioOriginal REAL,
        precioModificado REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE cargue (
        id INTEGER PRIMARY KEY,
        vehiculo TEXT,
        fecha TEXT,
        conductor TEXT,
        observaciones TEXT
  )
    ''');

    await db.execute('''
      CREATE TABLE cargue_factura (
        cargueId INTEGER,
        facturaId INTEGER,
        FOREIGN KEY (cargueId) REFERENCES cargue(id),
        FOREIGN KEY (facturaId) REFERENCES factura(id)
  )
    ''');
  }

  // PRODUCTOS
  static Future<int> insertarProducto(Producto producto) async {
    final db = await initDb();
    return await db.insert('producto', producto.toMap());
  }

  static Future<List<Producto>> obtenerProductos() async {
    final db = await initDb();
    final maps = await db.query('producto');
    return maps.map((e) => Producto.fromMap(e)).toList();
  }

  // CLIENTES
  static Future<int> insertarCliente(Cliente cliente) async {
    final db = await initDb();
    return await db.insert('cliente', cliente.toMap());
  }

  static Future<List<Cliente>> obtenerClientes() async {
    final db = await initDb();
    final maps = await db.query('cliente');
    return maps.map((e) => Cliente.fromMap(e)).toList();
  }

  // FACTURAS
  static Future<int> insertarFactura(Factura factura) async {
    final db = await initDb();
    return await db.insert('factura', factura.toMap());
  }

  static Future<List<Factura>> obtenerFacturas() async {
    final db = await initDb();
    final maps = await db.query('factura', orderBy: 'fecha DESC');
    return maps.map((e) => Factura.fromMap(e)).toList();
  }

  // DETALLES DE FACTURA
  static Future<void> insertarDetallesFactura(List<DetalleFactura> detalles) async {
    final db = await initDb();
    for (final d in detalles) {
      await db.insert('detalle_factura', d.toMap());
    }
  }

  static Future<List<DetalleFactura>> obtenerDetallesFactura(int facturaId) async {
    final db = await initDb();
    final maps = await db.query('detalle_factura', where: 'facturaId = ?', whereArgs: [facturaId]);
    return maps.map((e) => DetalleFactura.fromMap(e)).toList();
  }

  // para los cargues
  static Future<void> insertarCargue(Cargue cargue) async {
    final db = await initDb();

    await db.insert('cargue', {
      'id': cargue.id,
      'vehiculo': cargue.vehiculoAsignado,
      'fecha': cargue.fecha.toIso8601String(),
      'conductor': cargue.conductor,
      'observaciones': cargue.observaciones,
    });

    for (final facturaId in cargue.facturaIds) {
      await db.insert('cargue_factura', {
        'cargueId': cargue.id,
        'facturaId': facturaId,
      });
    }
  }

  // IMPORTAR INVENTARIO
  static Future<void> importarInventarioDesdeCSV() async {
    final prefs = await SharedPreferences.getInstance();
    final yaImportado = prefs.getBool('inventario_cargado') ?? false;
    if (yaImportado) return;

    try {
      final data = await rootBundle.loadString('assets/Inventario.csv');
      final rows = const CsvToListConverter(fieldDelimiter: ';').convert(data);
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final producto = Producto(
          codigo: row[0].toString(),
          nombre: row[1].toString(),
          presentacion: row[2].toString(),
          cantidad: double.tryParse(row[3].toString()) ?? 0,
          precio: double.tryParse(row[4].toString()) ?? 0,
        );
        await insertarProducto(producto);
      }
      await prefs.setBool('inventario_cargado', true);
    } catch (e) {
      print('Error al importar inventario: $e');
    }
  }

  // IMPORTAR CLIENTES
  static Future<void> importarClientesDesdeCSV() async {
    final prefs = await SharedPreferences.getInstance();
    //await prefs.remove('clientes_cargados');//fuerza a cargar la db SOLO PARA DESARROLLO (comenta esto después de que cargue bien)
    final yaImportado = prefs.getBool('clientes_cargados') ?? false;
    if (yaImportado) return;

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
    } catch (e) {
      print('Error al importar clientes: $e');
    }
  }

  // OBTENER CARGUES
  static Future<List<Cargue>> obtenerCargues() async {
    final db = await initDb();

    // 1. Consultar todos los registros de cargue
    final cargueMaps = await db.query('cargue');
    List<Cargue> cargues = [];
    for (final map in cargueMaps) {
      final cargueId = map['id'] as int;

      // 2. Consultar facturas asociadas a cada cargue
      final facturaMaps = await db.query(
        'cargue_factura',
        where: 'cargueId = ?',
        whereArgs: [cargueId],
      );
      final facturaIds = facturaMaps.map<int>((f) => f['facturaId'] as int).toList();
      final cargue = Cargue(
        id: cargueId,
        vehiculoAsignado: map['vehiculo'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        conductor: map['conductor'] as String,
        observaciones: (map['observaciones'] ?? '') as String,
        facturaIds: facturaIds,
      );
      cargues.add(cargue);
    }
    return cargues;
  }

  static Future<void> actualizarCargue(Cargue cargue) async {
    final db = await initDb();

    // 1. Actualizar los datos del cargue
    await db.update(
      'cargue',
      {
        'vehiculo': cargue.vehiculoAsignado,
        'fecha': cargue.fecha.toIso8601String(),
        'conductor': cargue.conductor,
        'observaciones': cargue.observaciones,
      },
      where: 'id = ?',
      whereArgs: [cargue.id],
    );

    // 2. Eliminar las facturas anteriores asociadas
    await db.delete(
      'cargue_factura',
      where: 'cargueId = ?',
      whereArgs: [cargue.id],
    );

    // 3. Insertar las nuevas facturas asociadas
    for (final facturaId in cargue.facturaIds) {
      await db.insert('cargue_factura', {
        'cargueId': cargue.id,
        'facturaId': facturaId,
      });
    }
  }

}