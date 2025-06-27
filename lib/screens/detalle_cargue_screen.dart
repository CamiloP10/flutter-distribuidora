import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cargue.dart';
import '../providers/ventas_provider.dart';
import '../providers/cliente_provider.dart';
import '../utils/pdf_generator.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'detalle_venta_screen.dart';

class DetalleCargueScreen extends StatelessWidget {
  final Cargue cargue;

  const DetalleCargueScreen({super.key, required this.cargue});

  @override
  Widget build(BuildContext context) {
    final ventasProvider = Provider.of<VentasProvider>(context);
    final clienteProvider = Provider.of<ClienteProvider>(context);
    final facturas = ventasProvider.facturas
        .where((f) => cargue.facturaIds.contains(f.id))
        .toList();
    final detalles = ventasProvider.getAllDetalles()
        .where((d) => cargue.facturaIds.contains(d.facturaId))
        .toList();
    final productos = ventasProvider.productosMap.values.toList();
    final clientes = clienteProvider.clientesMap;
    final format = DateFormat('dd/MM/yyyy HH:mm');

    final totalCargue = facturas.fold<double>(0, (sum, f) => sum + f.total);
    final totalEfectivo = facturas
        .where((f) => f.tipoPago == 'Contado')
        .fold<double>(0, (sum, f) => sum + f.pagado);
    final totalCredito = facturas
        .where((f) => f.tipoPago == 'Crédito')
        .fold<double>(0, (sum, f) => sum + f.saldoPendiente);

    return Scaffold(
      appBar: AppBar(title: Text('Cargue #${cargue.id}')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vehículo: ${cargue.vehiculoAsignado}'),
            Text('Conductor: ${cargue.conductor}'),
            Text('Fecha: ${format.format(cargue.fecha)}'),
            if (cargue.observaciones.isNotEmpty)
              Text('Observaciones: ${cargue.observaciones}'),
            const SizedBox(height: 8),
            Text('Total cargue: \$${totalCargue.toStringAsFixed(0)}'),
            Text('Total efectivo: \$${totalEfectivo.toStringAsFixed(0)}'),
            Text('Total crédito: \$${totalCredito.toStringAsFixed(0)}'),

            const Divider(),

            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Imprimir PDF'),
                onPressed: () async {
                  final pdf = await PdfGenerator.generarCarguePDF(
                    cargue: cargue,
                    facturas: facturas,
                    detalles: detalles,
                    productos: productos,
                    clientes: clientes,
                  );

                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/cargue_${cargue.id}.pdf');
                  await file.writeAsBytes(pdf);

                  await Share.shareXFiles(
                    [XFile(file.path)],
                    text: 'Cargue #${cargue.id}',
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar Factura'),
              onPressed: () async {
                await mostrarDialogoSeleccionFacturas(context, cargue);
              },
            ),

            const SizedBox(height: 10),
            const Text('Facturas asignadas:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: facturas.length,
                itemBuilder: (context, index) {
                  final f = facturas[index];
                  final cliente = clientes[f.clienteId ?? 0];
                  return ListTile(
                    title: Text("Factura #${f.id} - ${cliente?.nombre ?? 'Cliente NR'}"),
                    subtitle: Text("${format.format(f.fecha)} - \$${f.total.toStringAsFixed(0)}"),
                    onTap: () {
                      final detallesFactura = detalles.where((d) => d.facturaId == f.id).toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalleVentaScreen(
                            factura: f,
                            cliente: cliente,
                            detalles: detallesFactura,
                            productosMap: ventasProvider.productosMap,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> mostrarDialogoSeleccionFacturas(BuildContext context, Cargue cargue) async {
  final ventasProvider = Provider.of<VentasProvider>(context, listen: false);
  final facturasDisponibles = ventasProvider.facturas
      .where((f) => !cargue.facturaIds.contains(f.id))
      .toList();

  List<int> seleccionadas = [];

  await showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: Text('Seleccionar Facturas'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: facturasDisponibles.length,
            itemBuilder: (context, index) {
              final f = facturasDisponibles[index];
              return StatefulBuilder(
                builder: (context, setState) => CheckboxListTile(
                  title: Text('Factura #${f.id} - \$${f.total.toStringAsFixed(0)}'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(f.fecha)),
                  value: seleccionadas.contains(f.id),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        seleccionadas.add(f.id!);
                      } else {
                        seleccionadas.remove(f.id);
                      }
                    });
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (seleccionadas.isNotEmpty) {
                final nuevasFacturas = List<int>.from(cargue.facturaIds)..addAll(seleccionadas);
                final nuevoCargue = cargue.copyWith(facturaIds: nuevasFacturas.toSet().toList());
                await ventasProvider.actualizarCargue(nuevoCargue);

                Navigator.pop(context);

                // Refrescar vista
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetalleCargueScreen(cargue: nuevoCargue)),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  );
}
