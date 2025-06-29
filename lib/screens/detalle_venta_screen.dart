import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/factura.dart';
import '../models/detalle_factura.dart';
import '../models/producto.dart';
import '../models/cliente.dart';
import '../utils/pdf_generator.dart';

class DetalleVentaScreen extends StatelessWidget {
  final Factura factura;
  final Cliente? cliente;
  final List<DetalleFactura> detalles;
  final Map<int, Producto> productosMap;

  const DetalleVentaScreen({
    Key? key,
    required this.factura,
    required this.cliente,
    required this.detalles,
    required this.productosMap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'es_CO');
    final productosList = detalles.map((d) => productosMap[d.productoId]!).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Factura #${factura.id}')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${cliente?.nombre ?? 'NR'}'),
            Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(factura.fecha)}'),
            Text('Estado de Pago: ${factura.estadoPago}'),
            Text('Total: \$${currencyFormat.format(factura.total)}'),
            Text('Pagado: \$${currencyFormat.format(factura.pagado)}'),
            Text('Saldo Pendiente: \$${currencyFormat.format(factura.saldoPendiente)}'),
            Text('Tipo de Pago: ${factura.tipoPago}'),
            if (factura.informacion.isNotEmpty)
              Text('Observaciones: ${factura.informacion}'),
            const Divider(),

            // Botón para generar PDF y compartir
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generar PDF'),
                onPressed: () async {
                  final clienteFinal = cliente ?? Cliente(id: 0, nombre: 'Cliente eliminado', telefono: '', informacion: '');
                  final pdfBytes = await PdfGenerator.generarFacturaPDF(
                    factura: factura,
                    cliente: clienteFinal,
                    detalles: detalles,
                    productos: productosList,
                  );
                  await Printing.sharePdf(bytes: pdfBytes, filename: 'Factura_${factura.id}.pdf');
                },
              ),
            ),
            const SizedBox(height: 10),
            const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Expanded(
              child: ListView.builder(
                itemCount: detalles.length,
                itemBuilder: (context, index) {
                  final d = detalles[index];
                  final p = productosMap[d.productoId];
                  return ListTile(
                    title: Text('${p?.nombre ?? 'NR'} - ${p?.presentacion ?? ''}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cantidad: ${formatearCantidad(d.cantidad)}'),
                        if (d.precioOriginal != d.precioModificado)
                          Text(
                            'Precio original: \$${currencyFormat.format(d.precioOriginal)}',
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                        Text(
                          'Precio final U: \$${currencyFormat.format(d.precioModificado)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    trailing: Text(
                      ' Tot: \$${currencyFormat.format(d.subtotal)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  String formatearCantidad(double cantidad) {
    return cantidad % 1 == 0 ? cantidad.toInt().toString() : cantidad.toString();
  }
}