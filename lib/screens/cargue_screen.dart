import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cargue.dart';
import '../providers/cargue_provider.dart';
import '../providers/ventas_provider.dart';
import '../providers/cliente_provider.dart';
import '../models/cliente.dart';



class CargueScreen extends StatefulWidget {
  const CargueScreen({super.key});

  @override
  State<CargueScreen> createState() => _CargueScreenState();
}

class _CargueScreenState extends State<CargueScreen> {
  String nombreRepartidor = '';
  final Set<int> facturasSeleccionadas = {};

  @override
  Widget build(BuildContext context) {
    final ventasProvider = Provider.of<VentasProvider>(context);
    final cargueProvider = Provider.of<CargueProvider>(context);
    final facturas = ventasProvider.facturas;
    final clientes = Provider.of<ClienteProvider>(context).clientes;

    String obtenerNombreCliente(int? clienteId) {
      if (clienteId == null) return 'Cliente desconocido';
      final cliente = clientes.firstWhere(
            (c) => c.id == clienteId,
        orElse: () => Cliente(id: 0, nombre: 'Cliente no encontrado', telefono: '', informacion: ''),
      );
      return cliente.nombre;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Asignar Cargue")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: "Nombre del repartidor",
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => nombreRepartidor = val),
            ),
            const SizedBox(height: 16),
            const Text("Selecciona las facturas a asignar:"),
            const SizedBox(height: 8),
            Expanded(
              child: facturas.isEmpty
                  ? const Center(child: Text("No hay facturas disponibles"))
                  : ListView.builder(
                itemCount: facturas.length,
                itemBuilder: (context, index) {
                  final factura = facturas[index];
                  final idFactura = factura.id;
                  final isSelected = idFactura != null && facturasSeleccionadas.contains(idFactura);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true && idFactura != null) {
                          facturasSeleccionadas.add(idFactura);
                        } else {
                          facturasSeleccionadas.remove(idFactura);
                        }
                      });
                    },
                    // Ajusta esta línea según tu modelo:
                    title: Text("Factura #${idFactura} - ${obtenerNombreCliente(factura.clienteId)}"),
                    subtitle: Text(
                      "Total: \$${factura.total.toStringAsFixed(2)} - ${factura.fecha.toString().substring(0, 16)}",
                    ),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: nombreRepartidor.isNotEmpty && facturasSeleccionadas.isNotEmpty
                  ? () {
                final nuevoCargue = Cargue(
                  id: DateTime.now().millisecondsSinceEpoch,
                  nombreRepartidor: nombreRepartidor,
                  fecha: DateTime.now(),
                  facturaIds: facturasSeleccionadas.toList(),
                );

                cargueProvider.agregarCargue(nuevoCargue);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cargue creado exitosamente")),
                );

                Navigator.pop(context);
              }
                  : null,
              icon: const Icon(Icons.save),
              label: const Text("Guardar cargue"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


