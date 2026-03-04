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
  //para el cierre
  static Future<Uint8List> generarCierreDiaPDF({
    required DateTime fecha,
    required int totalFacturas,
    required double totalPagado,
    required double totalCredito,
    required double totalVentas,
    required double totalAbonos,
    required List<Map<String, dynamic>> detalleFacturas,
    required List<Map<String, dynamic>> abonosDetallados,
  }) async {
    final pdf = pw.Document();
    final format = DateFormat('dd/MM/yyyy');
    final money = NumberFormat('#,##0', 'es_CO');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, PdfPageFormat.a4.height),
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        build: (context) => [
          pw.Center(child: pw.Text('CIERRE DE VENTAS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('Fecha: ${format.format(fecha)}', style: const pw.TextStyle(fontSize: 9))),
          pw.Divider(),
          pw.Text('Total Facturas: $totalFacturas', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Total Venta del Día: \$${money.format(totalVentas)}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Total Recibido: \$${money.format(totalPagado)}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Total Créditos: \$${money.format(totalCredito)}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 6),
          pw.Text('Detalle de Facturas:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ...detalleFacturas.map((f) => pw.Text(
            '[  ]Fact #${f['id']} - ${f['cliente']}: \$${money.format(f['total'])}',
            style: const pw.TextStyle(fontSize: 8),
          )),

          pw.SizedBox(height: 6),
          pw.Text('Abonos a Créditos Anteriores:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Text('Total Abonos: \$${money.format(totalAbonos)}', style: const pw.TextStyle(fontSize: 9)),
          if (abonosDetallados.isNotEmpty)
            ...abonosDetallados.map((a) => pw.Text(
              'Fact #${a['facturaId']} - ${a['cliente']}: \$${money.format(a['monto'])}',
              style: const pw.TextStyle(fontSize: 8),
            )),
          pw.SizedBox(height: 8),
          pw.Text('Observaciones:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Text('_______________________________', style: pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 10),
          pw.Text('_______________________________', style: pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 10),
          pw.Divider(),
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

  // para las liquidaciones de cargues
  static Future<Uint8List> generarLiquidacionPDF({
    int? liquidacionId,
    DateTime? fechaManual,
    required double totalVendido,
    required double totalDevoluciones,
    required double totalCreditos,
    required double totalNequi,
    required double totalRecaudoCreditos,
    required double totalRecibido,
    required Map<String, int> cantidades,
    required Map<String, double> subtotales,
    required double monedas,
    required List<Cargue> carguesLiquidados,
    required List<Factura> todasLasFacturas,
    required List<Cliente> todosLosClientes,
  }) async {
    final pdf = pw.Document();
    final formatMiles = NumberFormat('#,###', 'es_CO');
    final formatFecha = DateFormat('yyyy-MM-dd HH:mm');

    final String fechaTexto = formatFecha.format(fechaManual ?? DateTime.now());
    final String tituloId = liquidacionId != null ? ' #$liquidacionId' : '';

    final Map<String, String> etiquetas = {
      '100k': '\$100.000', '50k': '\$50.000', '20k': '\$20.000',
      '10k': '\$10.000', '5k': '\$5.000', '2k': '\$2.000',
    };

    final double efectivoEsperado = (totalVendido - totalDevoluciones - totalCreditos - totalNequi) + totalRecaudoCreditos;
    final double diferencia = totalRecibido - efectivoEsperado;

    String labelDiferencia = 'Diferencia:';
    if (diferencia < 0) labelDiferencia = 'Faltante:';
    else if (diferencia > 0) labelDiferencia = 'A favor:';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, PdfPageFormat.a4.height),
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        build: (context) => [
          // 1. ENCABEZADO
          pw.Center(
            child: pw.Text(
              'LIQUIDACIÓN DE CAJA$tituloId',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Fecha: $fechaTexto', style: const pw.TextStyle(fontSize: 8)),
          pw.Divider(thickness: 0.5),

          // 2. TOTALES GENERALES
          _filaPdf('Total Vendido:', totalVendido, formatMiles),
          _filaPdf('Devoluciones:', -totalDevoluciones, formatMiles),
          _filaPdf('Créditos (Nuevos):', -totalCreditos, formatMiles),
          _filaPdf('Nequi (Virtual):', -totalNequi, formatMiles),
          _filaPdf('Recaudos:', totalRecaudoCreditos, formatMiles),
          pw.Divider(thickness: 0.5),

          // 3. BALANCE FINAL
          _filaPdf('Efectivo Esperado:', efectivoEsperado, formatMiles, bold: true),
          _filaPdf('Efectivo Recibido:', totalRecibido, formatMiles, bold: true),
          _filaPdf(labelDiferencia, diferencia, formatMiles, bold: true),
          pw.Divider(),

          // 4. ARQUEO DE BILLETES
          pw.Text('ARQUEO DE CAJA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          ...etiquetas.keys.map((key) {
            final cant = cantidades[key] ?? 0;
            final sub = subtotales[key] ?? 0;
            if (cant == 0) return pw.SizedBox();
            return _filaPdf('${etiquetas[key]} x $cant', sub, formatMiles, small: true);
          }).toList(),
          if (monedas > 0) _filaPdf('Monedas:', monedas, formatMiles, small: true),
          pw.Divider(),

          // 5. CARGUES LIQUIDADOS (Versión Final con Nombres de Clientes)
          pw.Text('CARGUES VINCULADOS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          pw.SizedBox(height: 4),
          ...carguesLiquidados.map((cargue) {
            final facturasDeEsteCargue = todasLasFacturas
                .where((f) => cargue.facturaIds.contains(f.id))
                .toList();

            final double totalDelCargue = facturasDeEsteCargue.fold(0.0, (sum, f) => sum + (f.total ?? 0));

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text('#${cargue.id} - ${cargue.vehiculoAsignado}',
                            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Text('\$${formatMiles.format(totalDelCargue)}',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Text('Cond: ${cargue.conductor}', style: const pw.TextStyle(fontSize: 6.5)),
                pw.SizedBox(height: 2),

                ...facturasDeEsteCargue.map((f) {
                  // LÓGICA DE BÚSQUEDA DEL CLIENTE
                  final clienteEncontrado = todosLosClientes.firstWhere(
                        (c) => c.id == f.clienteId,
                    orElse: () => Cliente(nombre: 'Cliente #${f.clienteId}', telefono: '', informacion: ''),
                  );

                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4, top: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                // Aquí usamos clienteEncontrado.nombre que viene de tu modelo Cliente
                                'Fact ${f.id}: ${clienteEncontrado.nombre}',
                                style: const pw.TextStyle(fontSize: 6.5),
                              ),
                            ),
                            pw.Text('\$${formatMiles.format(f.total)}',
                                style: const pw.TextStyle(fontSize: 6.5)),
                          ],
                        ),
                        // Opcional: Mostrar información adicional de la factura si existe
                        if (f.informacion.isNotEmpty)
                          pw.Text('Ref: ${f.informacion}', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey)),

                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Text('Obs: _________________________________',
                              style: pw.TextStyle(fontSize: 5, color: PdfColors.grey700)),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                pw.Divider(thickness: 0.3, height: 10, color: PdfColors.grey400),
              ],
            );
          }).toList(),
        ],
      ),
    );
    return pdf.save();
  }

// Función auxiliar para las filas (Añádela dentro de la misma clase PdfGenerator)
  static pw.Widget _filaPdf(String label, double valor, NumberFormat format, {bool bold = false, bool small = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: small ? 7 : 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(valor < 0 ? '-\$${format.format(valor.abs())}' : '\$${format.format(valor)}',
              style: pw.TextStyle(fontSize: small ? 7 : 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}