import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../models/abono.dart';
import '../models/cliente.dart';
import '../models/detalle_factura.dart';
import '../models/factura.dart';
import '../models/producto.dart';
import '../providers/ventas_provider.dart';
import '../utils/pdf_generator.dart';

// CLASE PRINCIPAL DEL WIDGET (LA QUE FALTABA)
class DetalleVentaScreen extends StatefulWidget {
  final Factura factura;
  final Cliente? cliente;
  final Map<int, Producto> productosMap;

  const DetalleVentaScreen({
    Key? key,
    required this.factura,
    required this.cliente,
    required this.productosMap,
  }) : super(key: key);

  @override
  State<DetalleVentaScreen> createState() => _DetalleVentaScreenState();
}

// CLASE DEL ESTADO MODIFICADA
class _DetalleVentaScreenState extends State<DetalleVentaScreen> {
  final currencyFormat = NumberFormat('#,##0', 'es_CO');

  // --- 1. Declarar el Future como una variable de estado ---
  late Future<List<DetalleFactura>> _detallesFuture;

  @override
  void initState() {
    super.initState();
    final ventasProvider = Provider.of<VentasProvider>(context, listen: false);

    // --- 2. Asignar el future en lugar de solo llamarlo ---
    _detallesFuture = ventasProvider.cargarDetallesFactura(widget.factura.id!);
  }

  Future<void> _actualizarFactura(Factura factura) async {
    final ventasProvider = Provider.of<VentasProvider>(context, listen: false);
    await ventasProvider.actualizarFactura(factura);
  }

  void _mostrarDialogoAbono(BuildContext context, Factura factura) {
    final TextEditingController abonoController = TextEditingController();

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
              final nuevoEstado = nuevoSaldo <= 0 ? 'Pagado' : 'Crédito';

              final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
              final observacionNueva =
                  'Abono \$${currencyFormat.format(abono)} el $ahora';
              final nuevaInfo = factura.informacion.isEmpty
                  ? observacionNueva
                  : '${factura.informacion}\n$observacionNueva';

              final facturaActualizada = factura.copyWith(
                pagado: nuevoPagado,
                saldoPendiente: nuevoSaldo,
                estadoPago: nuevoEstado,
                informacion: nuevaInfo,
              );

              await _actualizarFactura(facturaActualizada);

              final abonoModel = Abono(
                facturaId: factura.id!,
                monto: abono,
                fecha: DateTime.now(),
              );
              await DBHelper.insertarAbono(abonoModel);

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoReversion(BuildContext context, Factura factura) {
    final TextEditingController abonoController =
    TextEditingController(text: '0');

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
                  const SnackBar(content: Text('El abono debe ser válido')),
                );
                return;
              }

              final nuevoSaldo = factura.total - abono;

              final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
              final observacionNueva =
                  'Factura revertida a crédito con abono de \$${currencyFormat.format(abono)} el $ahora';
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

              await _actualizarFactura(facturaActualizada);

              if (abono > 0) {
                final nuevoAbono = Abono(
                  facturaId: factura.id!,
                  monto: abono,
                  fecha: DateTime.now(),
                );
                await DBHelper.insertarAbono(nuevoAbono);
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAgregarProducto(BuildContext context, Factura factura) {
    final TextEditingController cantidadCtrl = TextEditingController();
    final TextEditingController precioCtrl = TextEditingController();
    final TextEditingController productoCtrl = TextEditingController();
    Producto? productoSeleccionado;

    // Usamos el mapa de productos del provider que ya está en memoria
    final productosDisponibles = Provider.of<VentasProvider>(context, listen: false).productosMap.values.toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) { // Renombrado para evitar confusión
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
                      final Producto? seleccionado =
                      await showSearch<Producto>(
                        context: context,
                        delegate: ProductoSearchDelegate(productosDisponibles),
                      );

                      if (seleccionado != null) {
                        productoSeleccionado = seleccionado;
                        productoCtrl.text =
                        '${seleccionado.nombre} - ${seleccionado.presentacion}';
                        precioCtrl.text =
                            seleccionado.precio.toStringAsFixed(0);
                        setStateDialog(() {}); // Actualiza el modal
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                    const InputDecoration(labelText: 'Cantidad'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: precioCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                    const InputDecoration(labelText: 'Precio unitario'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
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
                    final nuevoSaldo = factura.estadoPago.toLowerCase() == 'pagado'
                        ? 0.0
                        : (nuevoTotal - factura.pagado);

                    final esPagado =
                        factura.estadoPago.toLowerCase() == 'pagado';

                    final facturaActualizada = factura.copyWith(
                      total: nuevoTotal,
                      pagado: esPagado ? nuevoTotal : factura.pagado,
                      saldoPendiente: nuevoSaldo,
                      estadoPago: factura.estadoPago,
                      tipoPago: factura.tipoPago,
                      informacion: factura.informacion,
                    );

                    await _actualizarFactura(facturaActualizada);

                    final ventasProvider =
                    Provider.of<VentasProvider>(context, listen: false);

                    // --- 3. Actualizamos el Future en el estado ---
                    setState(() {
                      _detallesFuture = ventasProvider.cargarDetallesFactura(factura.id!);
                    });

                    if (mounted) Navigator.pop(context);
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
    final ventasProvider = Provider.of<VentasProvider>(context);

    // 🔑 obtener siempre la versión fresca de la factura
    final factura = ventasProvider.facturas
        .firstWhere((f) => f.id == widget.factura.id);

    // Usamos el mapa de productos del provider
    final productosMap = ventasProvider.productosMap;

    return Scaffold(
      appBar: AppBar(title: Text('Factura #${factura.id}')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Cliente: ${widget.cliente?.nombre ?? 'NR'} - ${DateFormat('dd/MM/yyyy HH:mm').format(factura.fecha)}'),
            Text('Estado de Pago: ${factura.estadoPago}'),
            Text('Total: \$${currencyFormat.format(factura.total)}'),
            Text('Pagado: \$${currencyFormat.format(factura.pagado)}'),
            Text(
                'Saldo Pendiente: \$${currencyFormat.format(factura.saldoPendiente)}; Tipo de Pago: ${factura.tipoPago}'),
            if (factura.informacion.isNotEmpty)
              Text('Observaciones: ${factura.informacion}'),

            if (factura.estadoPago.toLowerCase() == 'crédito' ||
                factura.estadoPago.toLowerCase() == 'pagado')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Generar PDF'),
                      onPressed: () async {
                        // Obtenemos los detalles del future actual
                        final detalles = await _detallesFuture;

                        final clienteFinal = widget.cliente ??
                            Cliente(
                                id: 0,
                                nombre: 'NR',
                                telefono: '',
                                informacion: '');
                        final pdfBytes = await PdfGenerator.generarFacturaPDF(
                          factura: factura,
                          cliente: clienteFinal,
                          detalles: detalles,
                          productos: productosMap.values.toList(),
                        );
                        await Printing.sharePdf(
                            bytes: pdfBytes,
                            filename: 'Factura_${factura.id}.pdf');
                      },
                    ),
                    if (factura.estadoPago.toLowerCase() == 'crédito')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.attach_money),
                        label: const Text('Registrar Abono'),
                        onPressed: () => _mostrarDialogoAbono(context, factura),
                      ),
                    if (factura.estadoPago.toLowerCase() == 'pagado')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.undo),
                        label: const Text('Revertir a Crédito'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                        onPressed: () =>
                            _mostrarDialogoReversion(context, factura),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 10),
            const Text('Productos:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),

            // --- 4. Reemplazar el ListView.builder por un FutureBuilder ---
            Expanded(
              child: FutureBuilder<List<DetalleFactura>>(
                future: _detallesFuture, // Usamos el Future de nuestro estado
                builder: (context, snapshot) {
                  // Estado de Carga
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Estado de Error
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error al cargar detalles: ${snapshot.error}'),
                    );
                  }

                  // Estado de Éxito (pero vacío)
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No hay productos en esta factura.'),
                    );
                  }

                  // Estado de Éxito (con datos)
                  final detalles = snapshot.data!;

                  return ListView.builder(
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
                onPressed: () => _mostrarDialogoAgregarProducto(context, factura),
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  String formatearCantidad(double cantidad) {
    return cantidad % 1 == 0 ? cantidad.toInt().toString() : cantidad.toString();
  }
}

// --- CLASE DE BÚSQUEDA (LA QUE ESTABA AL FINAL) ---
class ProductoSearchDelegate extends SearchDelegate<Producto> {
  final List<Producto> productos;

  ProductoSearchDelegate(this.productos);

  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(
        context,
        Producto(
            id: 0,
            codigo: '',
            nombre: '',
            presentacion: '',
            cantidad: 0,
            precio: 0)),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions();

  Widget _buildSuggestions() {
    final sugerencias = productos
        .where((p) =>
    p.presentacion.toLowerCase().contains(query.toLowerCase()) ||
        p.nombre.toLowerCase().contains(query.toLowerCase()))
        .toList();

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