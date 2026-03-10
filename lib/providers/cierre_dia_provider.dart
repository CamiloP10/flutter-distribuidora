import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/factura.dart';
import '../models/detalle_factura.dart'; // Asegúrate de importar tus modelos
import '../models/producto.dart';

class CierreDiaProvider extends ChangeNotifier {
  DateTime fechaSeleccionada = DateTime.now();
  List<Factura> facturasDelDia = [];
  List<Map<String, dynamic>> abonosDetallados = [];
  Map<int, String> nombresClientes = {};

  // --- NUEVA DATA PARA EL DESPACHADOR ---
  // Estructura: Categoría -> { totalCat: double, productos: { Presentación: {cantidad, subtotal} } }
  Map<String, Map<String, dynamic>> resumenVentasGlobal = {};

  int totalFacturas = 0;
  double totalPagado = 0;
  double totalCredito = 0;
  double totalRecaudo = 0;
  double totalVentas = 0;
  double totalAbonosDelDia = 0;

  bool isLoading = true;

  void cambiarFecha(DateTime nuevaFecha) {
    fechaSeleccionada = nuevaFecha;
    cargarResumenDelDia();
  }

  // --- MÉTODO AUXILIAR PARA AGRUPAR (Reutilizable) ---
  Map<String, Map<String, dynamic>> procesarAgrupacion(
      List<Factura> facturas, List<DetalleFactura> detalles, List<Producto> productos) {
    final Map<String, Map<String, dynamic>> resultado = {};

    for (var f in facturas) {
      final detallesF = detalles.where((d) => d.facturaId == f.id);
      for (var det in detallesF) {
        final prod = productos.firstWhere(
              (p) => p.id == det.productoId,
          orElse: () => Producto(id: 0, codigo: '', nombre: 'VARIOS', presentacion: 'Sin definir', cantidad: 0, precio: 0),
        );

        final String cat = prod.nombre.toUpperCase(); // Categoría
        final String item = prod.presentacion;        // Producto específico
        final double sub = det.cantidad * det.precioModificado;

        if (!resultado.containsKey(cat)) {
          resultado[cat] = {'totalCat': 0.0, 'productos': <String, Map<String, double>>{}};
        }

        var prodsEnCat = resultado[cat]!['productos'] as Map<String, Map<String, double>>;
        if (!prodsEnCat.containsKey(item)) {
          prodsEnCat[item] = {'cantidad': 0, 'subtotal': 0};
        }

        prodsEnCat[item]!['cantidad'] = prodsEnCat[item]!['cantidad']! + det.cantidad;
        prodsEnCat[item]!['subtotal'] = prodsEnCat[item]!['subtotal']! + sub;
        resultado[cat]!['totalCat'] = resultado[cat]!['totalCat'] + sub;
      }
    }
    return resultado;
  }

  Future<void> cargarResumenDelDia() async {
    isLoading = true;
    notifyListeners();

    final db = await DBHelper.initDb();
    final fechaStr = fechaSeleccionada.toIso8601String().substring(0, 10);

    // 1. Obtener facturas
    final data = await db.rawQuery('SELECT * FROM factura WHERE DATE(fecha) = ?', [fechaStr]);
    facturasDelDia = data.map((e) => Factura.fromMap(e)).toList();

    // --- NUEVO: CARGAR DETALLES Y PRODUCTOS PARA EL RESUMEN ---
    final todosLosProductos = await DBHelper.obtenerProductos();
    final List<DetalleFactura> todosLosDetalles = await DBHelper.obtenerTodosLosDetalles();

    // Calculamos el resumen global del día
    resumenVentasGlobal = procesarAgrupacion(facturasDelDia, todosLosDetalles, todosLosProductos);
    // ---------------------------------------------------------

    totalFacturas = facturasDelDia.length;
    totalPagado = 0;
    totalCredito = 0;
    totalVentas = 0;

    for (var f in facturasDelDia) {
      totalPagado += f.pagado ?? 0;
      totalVentas += f.total ?? 0;
      if ((f.estadoPago ?? '').toLowerCase() == 'crédito') {
        totalCredito += f.saldoPendiente ?? 0;
      }
    }

    nombresClientes = {};
    final todosClientes = await DBHelper.obtenerClientes();
    for (final c in todosClientes) {
      nombresClientes[c.id!] = c.nombre;
    }

    // 2. Abonos (Tu lógica actual se mantiene)
    final abonosDelDia = await DBHelper.obtenerAbonosPorFecha(fechaSeleccionada);
    final facturaIdsHoy = facturasDelDia.map((f) => f.id).toSet();
    final abonosFacturasAnteriores = abonosDelDia.where((ab) => !facturaIdsHoy.contains(ab.facturaId)).toList();

    totalAbonosDelDia = 0;
    abonosDetallados = [];

    for (final ab in abonosFacturasAnteriores) {
      try {
        final factura = await DBHelper.obtenerFacturaPorId(ab.facturaId);
        if (factura.clienteId == null) continue;
        final cliente = await DBHelper.obtenerClientePorId(factura.clienteId!);

        abonosDetallados.add({
          'facturaId': ab.facturaId,
          'cliente': cliente.nombre,
          'monto': ab.monto,
        });
        totalAbonosDelDia += ab.monto;
      } catch (e) {
        print('❌ Error al obtener datos de abono: $e');
      }
    }

    totalRecaudo = totalPagado;
    isLoading = false;
    notifyListeners();
  }
}