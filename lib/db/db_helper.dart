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
import '../models/abono.dart';
import 'dart:io'; // Para manejar archivos (File)
import 'package:share_plus/share_plus.dart'; // Para compartir el archivo (backup)
import 'package:intl/intl.dart'; // Para la fecha de la db
import 'package:path_provider/path_provider.dart'; // Para carpeta temporal


class DBHelper {
  static Database? _db;

  static Future<Database> initDb() async {
    if (_db != null) return _db!;
    String path = join(await getDatabasesPath(), 'inventario.db');
    //_db = await openDatabase(path, version: 1, onCreate: _onCreate); crea la Db desde 0
    _db = await openDatabase(
      path,
      version: 3, //Aumenta la versión cuando se añada otra tabla a la db (actualizado a 3 03/03/2026)
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, //actualiza para no borrar datos de las tablas anteriores
    );
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

    // Tabla de Abonos oldVersion <2
    await db.execute('''
    CREATE TABLE abono (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      facturaId INTEGER,
      monto REAL,
      fecha TEXT,
      FOREIGN KEY (facturaId) REFERENCES factura(id)
    )
  ''');

    // Tablas liquidación y liquidación_cargue oldVersion <3
    await db.execute('''
  CREATE TABLE liquidacion (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha TEXT,
    totalEfectivo REAL,
    totalNequi REAL,
    totalCreditosNuevos REAL,
    totalCreditosAntiguos REAL,
    totalDevoluciones REAL,
    desgloseBilletes TEXT, 
    totalFinal REAL,
    observaciones TEXT
  )
''');

    await db.execute('''
  CREATE TABLE liquidacion_cargue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    liquidacionId INTEGER,
    cargueId INTEGER,
    FOREIGN KEY (liquidacionId) REFERENCES liquidacion (id) ON DELETE CASCADE,
    FOREIGN KEY (cargueId) REFERENCES cargue (id) ON DELETE CASCADE
  )
''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {//para quien viende de db2 v1
    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE abono (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        facturaId INTEGER,
        monto REAL,
        fecha TEXT,
        FOREIGN KEY (facturaId) REFERENCES factura(id)
      )
    ''');
    }

    if (oldVersion < 3) { // nuevas tablas para db 3 (v2.0 de la App)
      // 1. Crear tabla principal de liquidación
      await db.execute('''
      CREATE TABLE liquidacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT,
        totalEfectivo REAL,
        totalNequi REAL,
        totalCreditosNuevos REAL,
        totalCreditosAntiguos REAL,
        totalDevoluciones REAL,
        desgloseBilletes TEXT, 
        totalFinal REAL,
        observaciones TEXT
      )
    ''');

      // 2. Crear tabla intermedia con los nuevos nombres
      await db.execute('''
      CREATE TABLE liquidacion_cargue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        liquidacionId INTEGER,
        cargueId INTEGER,
        FOREIGN KEY (liquidacionId) REFERENCES liquidacion (id) ON DELETE CASCADE,
        FOREIGN KEY (cargueId) REFERENCES cargue (id) ON DELETE CASCADE
      )
    ''');
    }
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
  static Future<void> actualizarProducto(Producto producto) async {
    final db = await initDb();
    await db.update(
      'producto',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
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

  static Future<void> actualizarFactura(Factura factura) async {
    final db = await initDb();
    await db.update(
      'factura',
      factura.toMap(),
      where: 'id = ?',
      whereArgs: [factura.id],
    );
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

  //ABONOS
  // Insertar un nuevo abono
  static Future<void> insertarAbono(Abono abono) async {
    final db = await initDb();
    await db.insert('abono', abono.toMap());
  }
  // Obtener abonos por fecha
  static Future<List<Abono>> obtenerAbonosPorFecha(DateTime fecha) async {
    final db = await initDb();
    final fechaStr = fecha.toIso8601String().substring(0, 10); // yyyy-MM-dd
    final maps = await db.query(
      'abono',
      where: "DATE(fecha) = ?",
      whereArgs: [fechaStr],
    );
    return maps.map((e) => Abono.fromMap(e)).toList();
  }
  // obtener todos los abonos
  static Future<List<Abono>> obtenerTodosLosAbonos() async {
    final db = await initDb();
    final maps = await db.query('abono');
    return maps.map((e) => Abono.fromMap(e)).toList();
  }

  //para los cierres
  static Future<Factura> obtenerFacturaPorId(int id) async {
    final db = await initDb();
    final maps = await db.query('factura', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) throw Exception('Factura no encontrada');
    return Factura.fromMap(maps.first);
  }

  static Future<Cliente> obtenerClientePorId(int id) async {
    final db = await initDb();
    final maps = await db.query('cliente', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) throw Exception('Cliente no encontrado');
    return Cliente.fromMap(maps.first);
  }

  //MÉTODOS PARA LIQUIDACIONES (v2.0)

// 1. Guardar la liquidación y sus relaciones con cargues (Transacción segura)
  static Future<int> insertarLiquidacionCompleta(Map<String, dynamic> liquidacionMap, List<int> idsCargues) async {
    final db = await initDb();

    return await db.transaction((txn) async {
      // Insertar la liquidación principal
      int liquidacionId = await txn.insert('liquidacion', liquidacionMap);

      // Insertar cada relación con los cargues seleccionados
      for (var cargueId in idsCargues) {
        await txn.insert('liquidacion_cargue', {
          'liquidacionId': liquidacionId,
          'cargueId': cargueId,
        });
      }
      return liquidacionId;
    });
  }

// 2. Obtener todas las liquidaciones realizadas
  static Future<List<Map<String, dynamic>>> obtenerLiquidaciones() async {
    final db = await initDb();
    return await db.query('liquidacion', orderBy: 'fecha DESC');
  }

// 3. Obtener los cargues asociados a una liquidación específica
  static Future<List<int>> obtenerIdsCarguesDeLiquidacion(int liquidacionId) async {
    final db = await initDb();
    final maps = await db.query(
      'liquidacion_cargue',
      columns: ['cargueId'],
      where: 'liquidacionId = ?',
      whereArgs: [liquidacionId],
    );
    return maps.map((e) => e['cargueId'] as int).toList();
  }

  static Future<List<Map<String, dynamic>>> obtenerCarguesPorLiquidacion(int liquidacionId) async {
    final db = await initDb();
    return await db.rawQuery('''
    SELECT 
      c.*, 
      (SELECT SUM(f.total) FROM factura f 
       INNER JOIN cargue_factura cf ON f.id = cf.facturaId 
       WHERE cf.cargueId = c.id) as totalCargue,
      (SELECT GROUP_CONCAT(facturaId) FROM cargue_factura WHERE cargueId = c.id) as idsDeFacturas
    FROM cargue c
    INNER JOIN liquidacion_cargue rel ON c.id = rel.cargueId
    WHERE rel.liquidacionId = ?
  ''', [liquidacionId]);
  }

  static Future<List<Map<String, dynamic>>> obtenerHistorialLiquidaciones() async {
    final db = await initDb();
    // Traemos las liquidaciones ordenadas por fecha descendente
    return await db.query('liquidacion', orderBy: 'fecha DESC');
  }


  //FUNCIÓN COPIA DE SEGURIDAD
  static Future<void> exportarBaseDeDatos() async {
    try {
      // 1. Ubicar la base de datos original
      final dbFolder = await getDatabasesPath();
      final dbPath = join(dbFolder, 'inventario.db');
      final file = File(dbPath);

      if (await file.exists()) {
        // 2. Generar el nombre con fecha y hora (Ej: inventario_2023-10-27_15-30.db)
        final now = DateTime.now();
        final formatter = DateFormat('yyyy-MM-dd_HH-mm');
        final fechaHora = formatter.format(now);
        final nuevoNombre = 'inventario_$fechaHora.db';

        // 3. Obtener una carpeta temporal donde guardar la copia
        final tempDir = await getTemporaryDirectory();
        final tempPath = join(tempDir.path, nuevoNombre);

        // 4. Copiar el archivo original a la carpeta temporal con el nuevo nombre
        await file.copy(tempPath);

        // 5. Compartir el archivo COPIADO (que ya tiene el nombre correcto)
        await Share.shareXFiles(
          [XFile(tempPath)],
          text: 'Copia de seguridad generada el $fechaHora',
        );
      } else {
        print("❌ No se encontró el archivo de base de datos original.");
      }
    } catch (e) {
      print("❌ Error al exportar la base de datos: $e");
    }
  }

  // FUNCIÓN DE LIMPIEZA ACTUALIZADA v2.0
  static Future<void> limpiarDatosAntiguos() async {
    final db = await initDb();
    final fechaLimite = DateTime.now().subtract(const Duration(days: 60)).toIso8601String();// Calcula la fecha límite (60 días)

    try {
      // 1.ELIMINAR LIQUIDACIONES ANTIGUAS
      // Al borrar la liquidación, la tabla 'liquidacion_cargue' se limpia sola racias al ON DELETE CASCADE
      int liqBorradas = await db.delete(
        'liquidacion',
        where: 'fecha < ?',
        whereArgs: [fechaLimite],
      );
      if(liqBorradas > 0) print('📊 Limpieza: Se eliminaron $liqBorradas liquidaciones antiguas.');

      // 2. ELIMINAR FACTURAS ANTIGUAS Y PAGADAS
      final facturasParaBorrar = await db.query(
        'factura',
        columns: ['id'],
        where: 'fecha < ? AND saldoPendiente <= 0',
        whereArgs: [fechaLimite],
      );

      final idsFacturas = facturasParaBorrar.map((f) => f['id'] as int).toList();
      if (idsFacturas.isNotEmpty) {
        final idsString = idsFacturas.join(',');

        await db.execute('DELETE FROM detalle_factura WHERE facturaId IN ($idsString)');
        await db.execute('DELETE FROM cargue_factura WHERE facturaId IN ($idsString)');
        await db.execute('DELETE FROM abono WHERE facturaId IN ($idsString)');
        await db.execute('DELETE FROM factura WHERE id IN ($idsString)');
        print('🧹 Limpieza: Se eliminaron ${idsFacturas.length} facturas antiguas.');
      }
      // 3. ELIMINAR CARGUES ANTIGUOS
      final carguesParaBorrar = await db.query(
        'cargue',
        columns: ['id'],
        where: 'fecha < ?',
        whereArgs: [fechaLimite],
      );

      final idsCargues = carguesParaBorrar.map((c) => c['id'] as int).toList();

      if (idsCargues.isNotEmpty) {
        final idsCarguesString = idsCargues.join(',');

        await db.execute('DELETE FROM cargue_factura WHERE cargueId IN ($idsCarguesString)');
        await db.execute('DELETE FROM liquidacion_cargue WHERE cargueId IN ($idsCarguesString)');
        await db.execute('DELETE FROM cargue WHERE id IN ($idsCarguesString)');
        print('🚛 Limpieza: Se eliminaron ${idsCargues.length} cargues antiguos.');
      }
    } catch (e) {
      print('Error durante la limpieza automática: $e');
    }
  }
}