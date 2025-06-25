import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/detalle_factura.dart';
import '../models/factura.dart';
import '../db/db_helper.dart';
import 'package:intl/intl.dart';
import '../utils/pdf_generator.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
//para compartir en lugar de mostrar pdf
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class FacturaScreen extends StatefulWidget {//card
  final List<Cliente> clientes;
  final List<Producto> productos;

  const FacturaScreen({super.key, required this.clientes, required this.productos});

  @override
  State<FacturaScreen> createState() => _FacturaScreenState();
}

class _FacturaScreenState extends State<FacturaScreen> {
  Cliente? clienteSeleccionado;
  final List<DetalleFactura> detalles = [];
  final List<TextEditingController> cantidadControllers = [];
  final List<TextEditingController> precioControllers = [];

  final TextEditingController clienteBusquedaController = TextEditingController();
  final TextEditingController productoBusquedaController = TextEditingController();
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'es_CO');

  List<Cliente> clientesFiltrados = [];
  List<Producto> productosFiltrados = [];

  @override
  void initState() {
    super.initState();
    clientesFiltrados = [];
    productosFiltrados = [];
  }

  void filtrarClientes(String query) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      setState(() {
        clientesFiltrados = [];
      });
      return;
    }

    final encontrados = widget.clientes.where((c) {
      return c.nombre.toLowerCase().contains(q) ||
          c.informacion.toLowerCase().contains(q);
    }).toList();

    setState(() {
      clientesFiltrados = encontrados;

      // Si no se encontró nada, asignar cliente temporal
      if (encontrados.isEmpty) {
        clienteSeleccionado = Cliente(
          id: null,
          nombre: clienteBusquedaController.text.trim(),
          telefono: '',
          informacion: '',
        );
      }
    });
  }


  void filtrarProductos(String query) {
    final q = query.toLowerCase();
    if (q.isEmpty) {
      setState(() {
        productosFiltrados = [];
      });
      return;
    }
    setState(() {
      productosFiltrados = widget.productos.where((p) {
        return p.presentacion.toLowerCase().contains(q);
      }).toList();
    });
  }

  void agregarDetalle(Producto producto, double cantidad, double precioModificado) {
    // Verifica si el producto ya está agregado
    final yaExiste = detalles.any((d) => d.productoId == producto.id);
    if (yaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${producto.presentacion}" ya fue agregado.')),
      );
      return;
    }
    setState(() {
      detalles.add(DetalleFactura(
        facturaId: 0,
        productoId: producto.id!,
        cantidad: 1, // 1 por defecto
        precioOriginal: producto.precio,
        precioModificado: precioModificado,
      ));
      cantidadControllers.add(TextEditingController(text: '1'));
      precioControllers.add(TextEditingController(text: precioModificado.toStringAsFixed(0)));
    });
  }

  double calcularTotalFactura() {
    return detalles.fold(0.0, (sum, d) => sum + d.subtotal);
  }

  void mostrarDialogoPago() {
    String? tipoPagoSeleccionado;
    final pagoCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Información de Pago'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Método de pago:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: tipoPagoSeleccionado,
                    isExpanded: true,
                    hint: const Text('Seleccione un método'),
                    items: ['Pago total', 'Crédito'].map((tipo) {
                      return DropdownMenuItem(
                        value: tipo,
                        child: Text(tipo),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        tipoPagoSeleccionado = val;
                        if (val == 'Pago total') {
                          pagoCtrl.text = calcularTotalFactura().toStringAsFixed(0);
                        } else {
                          pagoCtrl.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pagoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Monto pagado'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: obsCtrl,
                    decoration: const InputDecoration(labelText: 'Observaciones'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    if (tipoPagoSeleccionado == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seleccione un método de pago')),
                      );
                      return;
                    }
                    final pago = double.tryParse(pagoCtrl.text);
                    if (pago == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingrese un monto pagado válido')),
                      );
                      return;
                    }
                    final total = calcularTotalFactura();
                    final saldo = total - pago;
                    final estado = saldo <= 0 ? 'Pagado' : 'Crédito';
                    final tipoGuardado = tipoPagoSeleccionado == 'Pago total' ? 'Contado' : 'Crédito';


                    final factura = Factura(
                      clienteId: clienteSeleccionado?.id,
                      fecha: DateTime.now(),
                      total: total,
                      pagado: pago,
                      tipoPago: tipoGuardado,
                      informacion: obsCtrl.text,
                      saldoPendiente: saldo,
                      estadoPago: estado,
                    );
                    final facturaId = await DBHelper.insertarFactura(factura);
                    final facturaConId = factura.copyWith(id: facturaId);

                    for (var d in detalles) {
                      d.facturaId = facturaId;
                    }
                    await DBHelper.insertarDetallesFactura(detalles);

                    // Guarda cliente antes de limpiar
                    final cliente = clienteSeleccionado;

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Factura registrada correctamente.')),
                    );

                    //Genera y muestra el PDF
                    /*await generarYMostrarPDF(
                      factura: factura,
                      cliente: cliente,
                      detalles: detalles,
                      productos: widget.productos,
                    );*/
                    //Genera y comparte el PDF
                    await generarYCompartirPDF(
                      factura: facturaConId,
                      cliente: cliente,
                      detalles: detalles,
                      productos: widget.productos,
                    );

                    // limpia la UI
                    setState(() {
                      clienteSeleccionado = null;
                      detalles.clear();
                      cantidadControllers.clear();
                      precioControllers.clear();
                      clienteBusquedaController.clear();
                      productoBusquedaController.clear();
                    });

                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /*Future<void> generarYMostrarPDF({
    required Factura factura,
    required Cliente? cliente,
    required List<DetalleFactura> detalles,
    required List<Producto> productos,
  }) async {
    final pdfBytes = await PdfGenerator.generarFacturaPDF(
      factura: factura,
      cliente: cliente,
      detalles: detalles,
      productos: productos,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }*/

  Future<void> generarYCompartirPDF({
    required Factura factura,
    required Cliente? cliente,
    required List<DetalleFactura> detalles,
    required List<Producto> productos,
  }) async {
    final pdfBytes = await PdfGenerator.generarFacturaPDF(
      factura: factura,
      cliente: cliente,
      detalles: detalles,
      productos: productos,
    );

    final outputDir = await getTemporaryDirectory();
    final file = File("${outputDir.path}/factura_${factura.id}.pdf");

    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Factura #${factura.id} generada desde la app.',
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Factura')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clientes:'),
            TextField(
              controller: clienteBusquedaController,
              decoration: InputDecoration(
                labelText: 'Buscar cliente',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: clienteBusquedaController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    clienteBusquedaController.clear();
                    filtrarClientes('');
                  },
                )
                    : null,
              ),
              onChanged: filtrarClientes,
            ),
            if (clienteSeleccionado != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Cliente seleccionado: ${clienteSeleccionado!.nombre}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        clienteSeleccionado = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Quitar cliente'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            if (clienteBusquedaController.text.isNotEmpty && clientesFiltrados.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: clientesFiltrados.length,
                  itemBuilder: (context, index) {
                    final c = clientesFiltrados[index];
                    return ListTile(
                      title: Text(c.nombre),
                      subtitle: Text(c.informacion),
                      onTap: () {
                        setState(() {
                          clienteSeleccionado = c;
                          clienteBusquedaController.clear();
                          clientesFiltrados = [];
                        });
                      },
                    );
                  },
                ),
              ),
            const Divider(),
            const Text('Productos:'),
            TextField(
              controller: productoBusquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar producto',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: productoBusquedaController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    productoBusquedaController.clear();
                    filtrarProductos('');
                  },
                )
                    : null,
              ),
              onChanged: filtrarProductos,
            ),
            const SizedBox(height: 8),
            if (productoBusquedaController.text.isNotEmpty && productosFiltrados.isNotEmpty)
              Column(
                children: productosFiltrados.map((p) {
                  return ListTile(
                    title: Text(p.presentacion),
                    subtitle: Text('Stock: ${p.cantidad} - \$${currencyFormat.format(p.precio)}'),
                    onTap: () {
                      agregarDetalle(p, 1, p.precio);
                      productoBusquedaController.clear();
                      filtrarProductos('');
                    },
                  );
                }).toList(),
              ),
            const Divider(),
            const Text('Detalle de factura:'),
            const SizedBox(height: 8),
            Column(
              children: detalles.asMap().entries.map((entry) {
                final index = entry.key;
                final d = entry.value;
                final producto = widget.productos.firstWhere((p) => p.id == d.productoId);
                return Card(
                  color: Colors.blue[100],
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('- ${producto.presentacion}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // Cantidad
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Cantidad:'),
                                  TextField(
                                    controller: cantidadControllers[index],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(hintText: 'Cant'),
                                    onChanged: (val) {
                                      final nuevaCantidad = double.tryParse(val);
                                      setState(() {
                                        detalles[index].cantidad = nuevaCantidad ?? 0;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Precio
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Precio:'),
                                  TextField(
                                    controller: precioControllers[index],
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) {
                                      final nuevoPrecio = double.tryParse(val) ?? d.precioModificado;
                                      setState(() {
                                        detalles[index].precioModificado = nuevoPrecio;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Subtotal
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Subtotal:'),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: (cantidadControllers[index].text.trim().isEmpty || d.cantidad == 0)
                                        ? const Text('---', style: TextStyle(color: Colors.grey))
                                        : Text('\$${currencyFormat.format(d.subtotal)}'),
                                  ),
                                ],
                              ),
                            ),

                            // Botón eliminar
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirmar = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Eliminar producto'),
                                    content: Text('¿Eliminar "${producto.presentacion}" de la factura?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmar == true) {
                                  setState(() {
                                    detalles.removeAt(index);
                                    cantidadControllers.removeAt(index);
                                    precioControllers.removeAt(index);
                                  });
                                }
                              },
                            ),

                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(),
            Text('Total: \$${currencyFormat.format(calcularTotalFactura())}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (detalles.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debe agregar al menos un producto.')),
                  );
                  return;
                }
                mostrarDialogoPago();
              },
              child: const Text('Registrar Factura'),
            ),
          ],
        ),
      ),
    );
  }
}