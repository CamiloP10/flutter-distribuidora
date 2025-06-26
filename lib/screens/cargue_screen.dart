import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cargue.dart';
import '../providers/cargue_provider.dart';
import '../providers/ventas_provider.dart';
import '../providers/cliente_provider.dart';
import '../models/cliente.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../db/db_helper.dart';
import '../utils/pdf_generator.dart';

import '../models/cargue.dart';

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CargueScreen extends StatefulWidget {
  const CargueScreen({super.key});

  @override
  State<CargueScreen> createState() => _CargueScreenState();
}

class _CargueScreenState extends State<CargueScreen> {
  String vehiculoAsignado = '';
  final Set<int> facturasSeleccionadas = {};
  final TextEditingController _conductorController = TextEditingController();
  final TextEditingController _observacionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ventasProvider = Provider.of<VentasProvider>(context);
    final cargueProvider = Provider.of<CargueProvider>(context);
    final facturas = ventasProvider.facturas;
    final clientes = Provider.of<ClienteProvider>(context).clientes;

    String obtenerNombreCliente(int? clienteId) {
      if (clienteId == null) return 'Cliente NR';
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
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Seleccione Vehículo de Cargue",
                border: OutlineInputBorder(),
              ),
              value: vehiculoAsignado.isEmpty ? null : vehiculoAsignado,
              items: [
                'JAC Roja',
                'JAC Blanca',
                'MotoCrg. Gris',
                'MotoCrg. Blanco',
                'Otro',
              ].map((vehiculo) {
                return DropdownMenuItem<String>(
                  value: vehiculo,
                  child: Text(vehiculo.isEmpty ? '-- Seleccionar --' : vehiculo),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  vehiculoAsignado = value ?? '';
                });
              },
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
                    title: Text("Factura #${idFactura} - ${obtenerNombreCliente(factura.clienteId)}"),
                    subtitle: Text(
                      "${factura.fecha.toString().substring(0, 16)} - Total: \$${factura.total.toStringAsFixed(0)}",
                    ),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: vehiculoAsignado.isNotEmpty && facturasSeleccionadas.isNotEmpty
                  ? () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Detalles del Cargue"),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _conductorController,
                              decoration: const InputDecoration(
                                labelText: "Nombre del conductor *",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _observacionController,
                              decoration: const InputDecoration(
                                labelText: "Observaciones",
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // cerrar diálogo
                          },
                          child: const Text("Cancelar"),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final conductor = _conductorController.text.trim();

                            if (conductor.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("El nombre del conductor es obligatorio")),
                              );
                              return;
                            }

                            final nuevoCargue = Cargue(
                              id: DateTime.now().millisecondsSinceEpoch,
                              vehiculoAsignado: vehiculoAsignado,
                              fecha: DateTime.now(),
                              facturaIds: facturasSeleccionadas.toList(),
                              conductor: conductor,
                              observaciones: _observacionController.text.trim(),
                            );

                            try {
                              // 1. Guardar en la base de datos
                              await DBHelper.insertarCargue(nuevoCargue);

                              // 2. Generar PDF
                              final pdfBytes = await PdfGenerator.generarCarguePDF(
                                cargue: nuevoCargue,
                                facturas: ventasProvider.facturas,
                                detalles: ventasProvider.getAllDetalles(),
                                productos: ventasProvider.productosMap.values.toList(),
                              );

                              // 3. Guardar archivo temporal y compartir
                              final outputDir = await getTemporaryDirectory();
                              final file = File("${outputDir.path}/cargue_${nuevoCargue.id}.pdf");

                              await file.writeAsBytes(pdfBytes);

                              await Share.shareXFiles(
                                [XFile(file.path)],
                                text: 'Cargue #${nuevoCargue.id} generado desde la app.',
                              );

                              // 3. Cerrar diálogos y mostrar confirmación
                              Navigator.of(context).pop(); // Cierra AlertDialog
                              Navigator.pop(context); // Regresa al home

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Cargue generado y compartido con éxito")),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error al guardar el cargue: $e")),
                              );
                            }
                          },

                          child: const Text("Confirmar"),
                        ),
                      ],
                    );
                  },
                );
              }
                  : null,
              icon: const Icon(Icons.fire_truck),
              label: const Text("Generar Cargue"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
