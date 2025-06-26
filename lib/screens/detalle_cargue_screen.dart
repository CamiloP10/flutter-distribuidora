import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/cargue.dart';
import '../providers/ventas_provider.dart';
import '../providers/cliente_provider.dart';
import '../utils/pdf_generator.dart';

import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';


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
                  //await Printing.sharePdf(bytes: pdf, filename: 'Cargue_${cargue.id}.pdf');
                },
              ),
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
