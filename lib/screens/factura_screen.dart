// lib/screens/factura_screen.dart

import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/detalle_factura.dart';
import '../models/factura.dart';
import '../db/db_helper.dart';

class FacturaScreen extends StatefulWidget {
  final List<Cliente> clientes;
  final List<Producto> productos;

  const FacturaScreen({super.key, required this.clientes, required this.productos});

  @override
  State<FacturaScreen> createState() => _FacturaScreenState();
}

class _FacturaScreenState extends State<FacturaScreen> {
  Cliente? clienteSeleccionado;
  final List<DetalleFactura> detalles = [];

  void agregarDetalle(Producto producto, int cantidad) {
    setState(() {
      detalles.add(DetalleFactura(
        id: detalles.length + 1,
        facturaId: 0, // se asigna cuando se guarde en BD
        productoId: producto.id!,
        cantidad: cantidad,
        precioUnitario: producto.precio,
      ));
    });
  }

  double calcularTotalFactura() {//calcular el total por factura
    return detalles.fold(
      0.0,
          (suma, detalle) => suma + detalle.total,
    );
  }

  //

  Future<void> registrarFactura() async {
    if (clienteSeleccionado == null || detalles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un cliente y agregue al menos un producto')),
      );
      return;
    }

    final nuevaFactura = Factura(
      id: 0,
      clienteId: clienteSeleccionado!.id!,
      fecha: DateTime.now(),
      total: calcularTotalFactura(),
    );

    // Suponiendo que los métodos de DBHelper son estáticos
    int facturaId = await DBHelper.insertarFactura(nuevaFactura);

    // Asociar el ID de factura a cada detalle
    for (var d in detalles) {
      d.facturaId = facturaId;
    }

    await DBHelper.insertarDetallesFactura(detalles);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Factura registrada correctamente')),
    );

    setState(() {
      clienteSeleccionado = null;
      detalles.clear();
    });
  }

  //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Factura')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<Cliente>(
              hint: const Text('Seleccione un cliente'),
              value: clienteSeleccionado,
              isExpanded: true,
              items: widget.clientes.map((cliente) {
                return DropdownMenuItem(
                  value: cliente,
                  child: Text(cliente.nombre),
                );
              }).toList(),
              onChanged: (nuevo) {
                setState(() => clienteSeleccionado = nuevo);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.productos.length,
                itemBuilder: (context, index) {
                  final p = widget.productos[index];
                  return ListTile(
                    title: Text('${p.nombre} - ${p.presentacion}'),
                    subtitle: Text('Disponible: ${p.cantidad}, Precio: \$${p.precio.toStringAsFixed(2)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) {
                            int cantidad = 1;
                            return AlertDialog(
                              title: Text('Agregar ${p.nombre}'),
                              content: TextField(
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Cantidad'),
                                onChanged: (value) => cantidad = int.tryParse(value) ?? 1,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    agregarDetalle(p, cantidad);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Agregar'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Detalle de factura:'),
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: detalles.length,
                itemBuilder: (context, index) {
                  final d = detalles[index];
                  final producto = widget.productos.firstWhere((p) => p.id == d.productoId);
                  return ListTile(
                    title: Text('${producto.nombre} - ${producto.presentacion}'),
                    subtitle: Text('Cantidad: ${d.cantidad}, Total: \$${d.total.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: registrarFactura,
                child: const Text('Registrar Factura'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
