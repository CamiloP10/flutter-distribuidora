import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/detalle_factura.dart';
import '../models/factura.dart';
import '../db/db_helper.dart';
import 'package:intl/intl.dart';
import '../utils/pdf_generator.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/cliente_provider.dart';
import '../providers/producto_provider.dart';

class FacturaScreen extends StatefulWidget {
  const FacturaScreen({super.key});

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

  void filtrarClientes(String query, List<Cliente> clientes) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => clientesFiltrados = []);
      return;
    }

    final encontrados = clientes.where((c) =>
    c.nombre.toLowerCase().contains(q) || c.informacion.toLowerCase().contains(q)).toList();

    setState(() {
      clientesFiltrados = encontrados;
    });
  }

  void filtrarProductos(String query, List<Producto> productos) {
    final q = query.toLowerCase();
    setState(() {
      productosFiltrados = q.isEmpty
          ? []
          : productos.where((p) => p.presentacion.toLowerCase().contains(q)).toList();
    });
  }

  void agregarDetalle(Producto producto, double precioModificado) {
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
        cantidad: 1,
        precioOriginal: producto.precio,
        precioModificado: precioModificado,
      ));
      cantidadControllers.add(TextEditingController(text: '1'));
      precioControllers.add(TextEditingController(text: precioModificado.toStringAsFixed(0)));
    });
  }

  Future<Cliente?> mostrarDialogoAgregarCliente(String nombre, List<Cliente> existentes) async {
    final telefonoCtrl = TextEditingController();
    final infoCtrl = TextEditingController();

    final yaExiste = existentes.any((c) => c.nombre.trim().toLowerCase() == nombre.trim().toLowerCase());
    if (yaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ya existe un cliente con ese nombre.')),
      );
      return null;
    }

    return await showDialog<Cliente>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Agregar nuevo cliente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nombre: $nombre'),
              TextField(
                controller: telefonoCtrl,
                decoration: InputDecoration(labelText: 'Teléfono (opcional)'),
              ),
              TextField(
                controller: infoCtrl,
                decoration: InputDecoration(labelText: 'Información adicional (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final nuevoCliente = Cliente(
                  id: null,
                  nombre: nombre.trim(),
                  telefono: telefonoCtrl.text.trim(),
                  informacion: infoCtrl.text.trim(),
                );

                final id = await DBHelper.insertarCliente(nuevoCliente);
                final clienteConId = Cliente(
                  id: id,
                  nombre: nuevoCliente.nombre,
                  telefono: nuevoCliente.telefono,
                  informacion: nuevoCliente.informacion,
                );

                final clienteProvider = Provider.of<ClienteProvider>(context, listen: false);
                clienteProvider.agregarClienteEnMemoria(clienteConId);

                Navigator.pop(context, clienteConId); // <-- Devuelve el cliente
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  double calcularTotalFactura() => detalles.fold(0.0, (sum, d) => sum + d.subtotal);

  Future<void> mostrarDialogoPago(List<Producto> productos) async {
    String? tipoPagoSeleccionado;
    final pagoCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    // Validar cliente antes de continuar
    if (clienteSeleccionado == null || clienteSeleccionado!.id == null) {
      final nombre = clienteBusquedaController.text.trim();
      if (nombre.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe seleccionar o guardar un cliente válido.')),
        );
        return;
      }

      // Verifica si ya existe un cliente con ese nombre
      final clientesExistentes = Provider.of<ClienteProvider>(context, listen: false).clientes;
      final yaExiste = clientesExistentes.any((c) =>
      c.nombre.trim().toLowerCase() == nombre.toLowerCase());

      if (yaExiste) {
        final existente = clientesExistentes.firstWhere((c) =>
        c.nombre.trim().toLowerCase() == nombre.toLowerCase());

        setState(() {
          clienteSeleccionado = existente;
        });
      } else {
        // Mostrar diálogo para completar datos del nuevo cliente
        await mostrarDialogoAgregarCliente(nombre, clientesExistentes);

        // Validar si el usuario cerró el diálogo sin guardar
        if (clienteSeleccionado == null || clienteSeleccionado!.id == null) {
          final nombre = clienteBusquedaController.text.trim();
          if (nombre.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Debe seleccionar o guardar un cliente válido.')),
            );
            return;
          }

          final clienteProvider = Provider.of<ClienteProvider>(context, listen: false);
          final yaExiste = clienteProvider.clientes.any(
                (c) => c.nombre.trim().toLowerCase() == nombre.toLowerCase(),
          );

          if (yaExiste) {
            final existente = clienteProvider.clientes.firstWhere(
                  (c) => c.nombre.trim().toLowerCase() == nombre.toLowerCase(),
            );
            setState(() {
              clienteSeleccionado = existente;
            });
          } else {
            final nuevo = await mostrarDialogoAgregarCliente(nombre, clienteProvider.clientes);
            if (nuevo != null) {
              setState(() {
                clienteSeleccionado = nuevo;
                clienteBusquedaController.clear();
                clientesFiltrados = [];
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cliente no fue registrado.')),
              );
              return;
            }
          }
        }
      }
    }


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
                    child: Text('Método de pago:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: tipoPagoSeleccionado,
                    isExpanded: true,
                    hint: const Text('Seleccione un método'),
                    items: ['Pago total', 'Crédito'].map((tipo) => DropdownMenuItem(
                        value: tipo, child: Text(tipo))).toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        tipoPagoSeleccionado = val;
                        pagoCtrl.text = val == 'Pago total' ? calcularTotalFactura().toStringAsFixed(0) : '';
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
                        const SnackBar(content: Text('Ingrese un monto válido')),
                      );
                      return;
                    }
                    final total = calcularTotalFactura();
                    final saldo = total - pago;
                    final factura = Factura(
                      clienteId: clienteSeleccionado?.id,
                      fecha: DateTime.now(),
                      total: total,
                      pagado: pago,
                      tipoPago: tipoPagoSeleccionado == 'Pago total' ? 'Contado' : 'Crédito',
                      informacion: obsCtrl.text,
                      saldoPendiente: saldo,
                      estadoPago: saldo <= 0 ? 'Pagado' : 'Crédito',
                    );
                    final facturaId = await DBHelper.insertarFactura(factura);
                    for (var d in detalles) {
                      d.facturaId = facturaId;
                    }
                    await DBHelper.insertarDetallesFactura(detalles);

                    await generarYCompartirPDF(
                      factura: factura.copyWith(id: facturaId),
                      cliente: clienteSeleccionado,
                      detalles: detalles,
                      productos: productos,
                    );

                    Navigator.pop(context);
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
    final file = File("${outputDir.path}/factura_\${factura.id}.pdf");
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], text: 'MAYORISTA LA BELLEZA ®');
  }

  @override
  Widget build(BuildContext context) {
    final clientes = Provider.of<ClienteProvider>(context).clientes;
    final productos = Provider.of<ProductoProvider>(context).productos;

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
                    filtrarClientes('', clientes);
                  },
                )
                    : null,
              ),
              onChanged: (value) => filtrarClientes(value, clientes),
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
                    filtrarProductos('', productos);
                  },
                )
                    : null,
              ),
              onChanged: (value) => filtrarProductos(value, productos),
            ),
            const SizedBox(height: 8),
            if (productoBusquedaController.text.isNotEmpty && productosFiltrados.isNotEmpty)
              Column(
                children: productosFiltrados.map((p) {
                  return ListTile(
                    title: Text(p.presentacion),
                    subtitle: Text('Stock: ${p.cantidad} - \$${currencyFormat.format(p.precio)}'),
                    onTap: () {
                      agregarDetalle(p, p.precio);
                      productoBusquedaController.clear();
                      filtrarProductos('', productos);
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
                final producto = productos.firstWhere((p) => p.id == d.productoId);
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
              onPressed: () async {
                if (detalles.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debe agregar al menos un producto.')),
                  );
                  return;
                }

                final clienteProvider = Provider.of<ClienteProvider>(context, listen: false);
                final clientes = clienteProvider.clientes;

                final nombreCliente = clienteBusquedaController.text.trim();

                // Si no hay cliente seleccionado y se escribió un nombre nuevo
                if ((clienteSeleccionado == null || clienteSeleccionado!.id == null) && nombreCliente.isNotEmpty) {
                  final yaExiste = clientes.any((c) =>
                  c.nombre.trim().toLowerCase() == nombreCliente.toLowerCase());

                  if (yaExiste) {
                    final existente = clientes.firstWhere((c) =>
                    c.nombre.trim().toLowerCase() == nombreCliente.toLowerCase());
                    setState(() {
                      clienteSeleccionado = existente;
                    });
                  } else {
                    final nuevo = await mostrarDialogoAgregarCliente(nombreCliente, clientes);
                    if (nuevo != null) {
                      setState(() {
                        clienteSeleccionado = nuevo;
                        clienteBusquedaController.clear();
                        clientesFiltrados = [];
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cliente no fue registrado.')),
                      );
                      return;
                    }
                  }
                }
                // Validación final
                if (clienteSeleccionado == null || clienteSeleccionado!.id == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debe seleccionar o guardar un cliente válido.')),
                  );
                  return;
                }

                mostrarDialogoPago(productos);
              },
              child: const Text('Registrar Factura'),
            ),
          ],
        ),
      ),
    );
  }
}