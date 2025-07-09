import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/factura.dart';
import '../models/detalle_factura.dart';
import '../models/producto.dart';
import '../models/cliente.dart';
import '../utils/pdf_generator.dart';
import '../db/db_helper.dart';
import 'package:intl/intl.dart';


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

  void _mostrarDialogoAbono(BuildContext context) {
    final TextEditingController abonoController = TextEditingController();
    final currencyFormat = NumberFormat('#,##0', 'es_CO');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrar Abono'),
        content: TextField(
          controller: abonoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Valor del abono'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final abono = double.tryParse(abonoController.text) ?? 0;
              if (abono <= 0) return;

              final nuevoPagado = factura.pagado + abono;
              final nuevoSaldo = factura.total - nuevoPagado;
              final nuevoEstado = nuevoSaldo <= 0 ? 'Pagado' : factura.estadoPago;

              final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
              final observacionNueva = 'Abono \$${currencyFormat.format(abono)} el $ahora';
              final nuevaInfo = factura.informacion.isEmpty
                  ? observacionNueva
                  : '${factura.informacion}\n$observacionNueva';

              final facturaActualizada = factura.copyWith(
                pagado: nuevoPagado,
                saldoPendiente: nuevoSaldo,
                estadoPago: nuevoEstado,
                informacion: nuevaInfo,
              );

              await DBHelper.actualizarFactura(facturaActualizada);

              Navigator.pop(context);
              Navigator.pop(context); // Cierra esta pantalla
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleVentaScreen(
                    factura: facturaActualizada,
                    cliente: cliente,
                    detalles: detalles,
                    productosMap: productosMap,
                  ),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoReversion(BuildContext context) {
    final TextEditingController abonoController = TextEditingController();
    final currencyFormat = NumberFormat('#,##0', 'es_CO');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambiar factura a Crédito'),
        content: TextField(
          controller: abonoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Abono:'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final abono = double.tryParse(abonoController.text) ?? 0;
              if (abono <= 0 || abono > factura.total) return;

              final nuevoSaldo = factura.total - abono;

              final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
              final observacionNueva = 'Factura revertida a crédito con abono de \$${currencyFormat.format(abono)} el $ahora';
              final nuevaInfo = factura.informacion.isEmpty
                  ? observacionNueva
                  : '${factura.informacion}\n$observacionNueva';

              final facturaActualizada = factura.copyWith(
                pagado: abono,
                saldoPendiente: nuevoSaldo,
                estadoPago: 'Crédito',
                tipoPago: 'Crédito',
                informacion: nuevaInfo,
              );

              await DBHelper.actualizarFactura(facturaActualizada);

              Navigator.pop(context);
              Navigator.pop(context); // Cierra esta pantalla
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleVentaScreen(
                    factura: facturaActualizada,
                    cliente: cliente,
                    detalles: detalles,
                    productosMap: productosMap,
                  ),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

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

            if (factura.estadoPago.toLowerCase() == 'crédito')
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.attach_money),
                  label: const Text('Registrar Abono'),
                  onPressed: () {
                    _mostrarDialogoAbono(context);
                  },
                ),
              ),
            const Divider(),

            if (factura.estadoPago.toLowerCase() == 'pagado')
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('Revertir a Crédito'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () {
                    _mostrarDialogoReversion(context);
                  },
                ),
              ),

            // Botón para generar PDF y compartir
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generar PDF'),
                onPressed: () async {
                  final clienteFinal = cliente ?? Cliente(id: 0, nombre: 'NR', telefono: '', informacion: '');
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