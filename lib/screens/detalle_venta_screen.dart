import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/factura.dart';
import '../models/detalle_factura.dart';
import '../models/producto.dart';
import '../models/cliente.dart';
import '../utils/pdf_generator.dart';
import '../db/db_helper.dart';

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
              if (abono < 0) return;

              final nuevoPagado = factura.pagado + abono;
              final nuevoSaldo = factura.total - nuevoPagado;
              final nuevoEstado = nuevoSaldo <= 0 ? 'Pagado' : 'Crédito';

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
    final TextEditingController abonoController = TextEditingController(text: '0');
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
              if (abono < 0 || abono > factura.total) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El abono debe ser mayor o igual a 0 y no puede superar el total')),
                );
                return;
              }

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

  void _mostrarDialogoAgregarProducto(BuildContext context) {
    final TextEditingController cantidadCtrl = TextEditingController();
    final TextEditingController precioCtrl = TextEditingController();
    final TextEditingController productoCtrl = TextEditingController();
    Producto? productoSeleccionado;

    final productosDisponibles = productosMap.values.toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Agregar producto a la factura'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: productoCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Producto',
                      suffixIcon: Icon(Icons.search),
                    ),
                    onTap: () async {
                      final Producto? seleccionado = await showSearch<Producto>(
                        context: context,
                        delegate: ProductoSearchDelegate(productosDisponibles),
                      );

                      if (seleccionado != null) {
                        productoSeleccionado = seleccionado;
                        productoCtrl.text = '${seleccionado.nombre} - ${seleccionado.presentacion}';
                        precioCtrl.text = seleccionado.precio.toStringAsFixed(0);
                        setState(() {});
                      }

                      if (seleccionado != null) {
                        setState(() {
                          productoSeleccionado = seleccionado;
                          productoCtrl.text = '${seleccionado.nombre} - ${seleccionado.presentacion}';
                          precioCtrl.text = seleccionado.precio.toStringAsFixed(0);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: precioCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio unitario'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (productoSeleccionado == null) return;
                    final cantidad = double.tryParse(cantidadCtrl.text) ?? 0;
                    final precio = double.tryParse(precioCtrl.text) ?? 0;
                    if (cantidad <= 0 || precio <= 0) return;

                    final nuevoDetalle = DetalleFactura(
                      facturaId: factura.id!,
                      productoId: productoSeleccionado!.id!,
                      cantidad: cantidad,
                      precioOriginal: productoSeleccionado!.precio,
                      precioModificado: precio,
                    );

                    await DBHelper.insertarDetallesFactura([nuevoDetalle]);

                    final nuevoTotal = factura.total + (cantidad * precio);
                    // mantiene el estado pagado
                    final nuevoSaldo = factura.estadoPago.toLowerCase() == 'pagado'
                        ? 0
                        : nuevoTotal - factura.pagado;

                    final esPagado = factura.estadoPago.toLowerCase() == 'pagado';

                    final facturaActualizada = factura.copyWith(
                      total: nuevoTotal,
                      pagado: esPagado ? nuevoTotal : factura.pagado,
                      saldoPendiente: esPagado ? 0 : nuevoSaldo.toDouble(),
                      estadoPago: factura.estadoPago,
                      tipoPago: factura.tipoPago,
                      informacion: factura.estadoPago.toLowerCase() == 'pagado' ? '' : factura.informacion,
                    );

                    await DBHelper.actualizarFactura(facturaActualizada);

                    if (context.mounted) {
                      Navigator.pop(context); // Cierra el diálogo
                      Navigator.pop(context); // Cierra la pantalla actual
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalleVentaScreen(
                            factura: facturaActualizada,
                            cliente: cliente,
                            detalles: [...detalles, nuevoDetalle],
                            productosMap: productosMap,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
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
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agregar Item'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () => _mostrarDialogoAgregarProducto(context),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      /*
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoAgregarProducto(context),
        icon: const Icon(Icons.add),
        label: const Text('Agregar Item'),
        backgroundColor: Colors.teal,
      ),*/
    );
  }
  String formatearCantidad(double cantidad) {
    return cantidad % 1 == 0 ? cantidad.toInt().toString() : cantidad.toString();
  }
}

class ProductoSearchDelegate extends SearchDelegate<Producto> {
  final List<Producto> productos;

  ProductoSearchDelegate(this.productos);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, Producto(id: 0, codigo: '', nombre: '', presentacion: '', cantidad: 0, precio: 0)),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions();

  Widget _buildSuggestions() {
    final sugerencias = productos.where((p) =>
    p.presentacion.toLowerCase().contains(query.toLowerCase()) ||
        p.nombre.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: sugerencias.length,
      itemBuilder: (context, index) {
        final prod = sugerencias[index];
        return ListTile(
          title: Text('${prod.nombre} - ${prod.presentacion}'),
          subtitle: Text('Precio: \$${prod.precio.toStringAsFixed(0)}'),
          onTap: () => close(context, prod),
        );
      },
    );
  }
}

