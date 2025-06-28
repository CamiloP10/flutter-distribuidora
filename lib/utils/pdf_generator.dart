import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

import '../models/factura.dart';
import '../models/detalle_factura.dart';
import '../models/producto.dart';
import '../models/cliente.dart';
import '../models/cargue.dart';

class PdfGenerator {
  static Future<Uint8List> generarFacturaPDF({
    required Factura factura,
    required Cliente? cliente,
    required List<DetalleFactura> detalles,
    required List<Producto> productos,
  }) async {
    final pdf = pw.Document();
    final logo = await _cargarLogo();
    final qr = await _cargarQr();
    final formatMiles = NumberFormat('#,###', 'es_CO');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, PdfPageFormat.a4.height),
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        build: (context) => [
          pw.Center(child: pw.Image(logo, width: 85)),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('MAYORISTA LA BELLEZA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('NIT: 79.736.209-9', style: pw.TextStyle(fontSize: 9))),
          pw.Center(child: pw.Text('Tel: 313 390 9767', style: pw.TextStyle(fontSize: 9))),
          pw.Center(child: pw.Text('labellezamayorista@gmail', style: pw.TextStyle(fontSize: 9))),
          pw.Center(child: pw.Text('Mochuelo bajo', style: pw.TextStyle(fontSize: 9))),
          pw.Divider(),
          pw.SizedBox(height: 5),
          pw.Text('Factura N°: ${factura.id}', style: pw.TextStyle(fontSize: 9)),
          pw.Text('Fecha: ${factura.fecha.toString().substring(0, 16)}', style: pw.TextStyle(fontSize: 9)),
          pw.Text('Estado: ${factura.estadoPago}', style: pw.TextStyle(fontSize: 9)),
          pw.Text('Cliente: ${cliente?.nombre ?? '--'}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Tel: ${cliente?.telefono ?? '—-'}', style: const pw.TextStyle(fontSize: 9)),
          pw.Divider(),
          pw.Text('# Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Cantidad', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Precio', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('SubTotal', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
          pw.Divider(),

          ...detalles.map((d) {
            final producto = productos.firstWhere((p) => p.id == d.productoId);
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('# ${producto.presentacion}', style: const pw.TextStyle(fontSize: 9)),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${formatearNumero(d.cantidad)}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('\$${formatMiles.format(d.precioModificado)}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('\$${formatMiles.format(d.cantidad * d.precioModificado)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],
            );
          }).toList(),

          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('\$${formatMiles.format(factura.total)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Text('Pagado: \$${formatMiles.format(factura.pagado)}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Saldo: \$${formatMiles.format(factura.saldoPendiente)}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.Center(child: pw.Text('WHATSAPP:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Image(qr, width: 70)),
          pw.SizedBox(height: 5),
          pw.Text(
            'ESTA FACTURA SE ASIMILA EN TODOS SUS EFECTOS A UNA LETRA DE CAMBIO (ART 774 DEL CODIGO DE COMERCIO)',
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('GRACIAS POR SU COMPRA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
    return pdf.save();
  }

  // Cargue en pdf
  static Future<Uint8List> generarCarguePDF({
    required Cargue cargue,
    required List<Factura> facturas,
    required List<DetalleFactura> detalles,
    required List<Producto> productos,
    required Map<int, Cliente> clientes,
  }) async {
    final pdf = pw.Document();
    final formatFecha = DateFormat('yyyy-MM-dd HH:mm');
    final formatMiles = NumberFormat('#,###', 'es_CO');

    // 1. Filtrar solo las facturas seleccionadas en el cargue
    final facturasCargue = facturas
        .where((f) => cargue.facturaIds.contains(f.id))
        .toList();

    // 2. Calcular total general del cargue
    final totalCargue = facturasCargue.fold<double>(
      0,
          (sum, f) => sum + f.total,
    );
    final totalCredito = facturasCargue.fold<double>(0, (sum, f) => sum + f.saldoPendiente);
    final totalPagado = facturasCargue.fold<double>(0, (sum, f) => sum + f.pagado);

    // 3. Filtrar detalles solo de esas facturas
    final detallesFiltrados = detalles
        .where((d) => cargue.facturaIds.contains(d.facturaId))
        .toList();

    // 4. Agrupar productos por productoId
    final Map<int, double> cantidadPorProducto = {};
    for (final d in detallesFiltrados) {
      cantidadPorProducto[d.productoId] =
          (cantidadPorProducto[d.productoId] ?? 0) + d.cantidad;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, PdfPageFormat.a4.height),
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'CARGUE DE PEDIDOS',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Vehículo: ${cargue.vehiculoAsignado}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Conductor: ${cargue.conductor}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Fecha: ${formatFecha.format(cargue.fecha)}', style: const pw.TextStyle(fontSize: 9)),
          if (cargue.observaciones.isNotEmpty)
            pw.Text('Obs: ${cargue.observaciones}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Facturas asignadas:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Divider(),
          ...facturasCargue.map((f) {
            final clienteNombre = clientes[f.clienteId ?? 0]?.nombre ?? 'NR';
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('factura #${f.id} -$clienteNombre', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Total: \$${formatMiles.format(f.total)}      Efectivo.[  ]', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Otro:__________________________', style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(thickness: 0.5),
                //pw.SizedBox(height: 4),
              ],
            );
          }),

          pw.Text('Total cargue: \$${formatMiles.format(totalCargue)}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text('Total efectivo: \$${formatMiles.format(totalPagado)}',
              style: pw.TextStyle(fontSize: 9)),
          pw.Text('Total crédito: \$${formatMiles.format(totalCredito)}',
              style: pw.TextStyle(fontSize: 9)),

          pw.Divider(),

          pw.Text('Resumen de productos:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ...cantidadPorProducto.entries.map((entry) {
            final producto = productos.firstWhere(
                    (p) => p.id == entry.key,
                orElse: () => Producto(
                    id: 0, codigo: '', nombre: 'Producto desconocido',
                    presentacion: '', cantidad: 0, precio: 0));

            final nombre = producto.presentacion.isNotEmpty
                ? producto.presentacion
                : producto.nombre;

            final cantidad = formatearNumero(entry.value);

            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('[  ]', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(width: 4), // Espacio entre el cuadro y el texto
                  pw.Expanded(
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: '(x$cantidad) ',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.TextSpan(
                            text: nombre,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.normal,),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          pw.Divider(),
          pw.Center(
            child: pw.Text('FIN DEL CARGUE',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<pw.ImageProvider> _cargarLogo() async {
    final data = await rootBundle.load('assets/icon.png');
    final bytes = data.buffer.asUint8List();
    return pw.MemoryImage(bytes);
  }

  static Future<pw.ImageProvider> _cargarQr() async {
    final data = await rootBundle.load('assets/qr.png');
    final bytes = data.buffer.asUint8List();
    return pw.MemoryImage(bytes);
  }

  static String formatearNumero(double numero) {
    return numero % 1 == 0 ? numero.toInt().toString() : numero.toString();
  }
}