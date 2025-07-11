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
import '../models/factura.dart';
import '../models/detalle_factura.dart';

class DetalleCargueScreen extends StatefulWidget {
  final Cargue cargue;

  const DetalleCargueScreen({super.key, required this.cargue});

  @override
  State<DetalleCargueScreen> createState() => _DetalleCargueScreenState();
}

class _DetalleCargueScreenState extends State<DetalleCargueScreen> {
  List<Factura> facturas = [];
  List<DetalleFactura> detalles = [];

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    final ventasProvider = Provider.of<VentasProvider>(context, listen: false);
    await ventasProvider.cargarDatos();

    setState(() {
      facturas = ventasProvider.facturas
          .where((f) => widget.cargue.facturaIds.contains(f.id))
          .toList();

      detalles = ventasProvider.getAllDetalles()
          .where((d) => widget.cargue.facturaIds.contains(d.facturaId))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ventasProvider = Provider.of<VentasProvider>(context);
    final clienteProvider = Provider.of<ClienteProvider>(context);
    final productos = ventasProvider.productosMap.values.toList();
    final clientes = clienteProvider.clientesMap;
    final format = DateFormat('dd/MM/yyyy HH:mm');

    final totalCargue = facturas.fold<double>(0, (sum, f) => sum + f.total);
    final totalEfectivo = facturas.fold<double>(0, (sum, f) => sum + f.pagado);
    final totalCredito = facturas.fold<double>(0, (sum, f) => sum + f.saldoPendiente);

    return Scaffold(
      appBar: AppBar(title: Text('Cargue #${widget.cargue.id}')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vehículo: ${widget.cargue.vehiculoAsignado}'),
            Text('Conductor: ${widget.cargue.conductor}'),
            Text('Fecha: ${format.format(widget.cargue.fecha)}'),
            if (widget.cargue.observaciones.isNotEmpty)
              Text('Observaciones: ${widget.cargue.observaciones}'),
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
                    cargue: widget.cargue,
                    facturas: facturas,
                    detalles: detalles,
                    productos: productos,
                    clientes: clientes,
                  );

                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/cargue_${widget.cargue.id}.pdf');
                  await file.writeAsBytes(pdf);

                  await Share.shareXFiles(
                    [XFile(file.path)],
                    text: 'Cargue #${widget.cargue.id}',
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar Factura'),
              onPressed: () async {
                await ventasProvider.cargarDatos(); // recarga datos actualizados
                await mostrarDialogoSeleccionFacturas(context, widget.cargue);
                await cargarDatos(); // actualizar la pantalla después de agregar
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

                  final detallesFactura = detalles.where((d) => d.facturaId == f.id).toList();

                  return ListTile(
                    title: Text("Factura #${f.id} - ${cliente?.nombre ?? 'Cliente NR'}"),
                    subtitle: Text("${format.format(f.fecha)} - \$${f.total.toStringAsFixed(0)}"),
                    onTap: () async {
                      await Navigator.push(
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
                      await cargarDatos(); // recarga después de regresar
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
  int limiteFacturas = 20;

  await showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          final facturasLimitadas = facturasDisponibles.take(limiteFacturas).toList();
          final hayMas = facturasDisponibles.length > facturasLimitadas.length;

          return AlertDialog(
            title: const Text('Seleccionar Facturas'),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: facturasLimitadas.length,
                      itemBuilder: (context, index) {
                        final f = facturasLimitadas[index];
                        final clienteNombre = ventasProvider.getCliente(f.clienteId)?.nombre ?? 'Cliente NR';
                        return CheckboxListTile(
                          title: Text('F. #${f.id} - $clienteNombre'),
                          subtitle: Text(
                            '${DateFormat('dd/MM/yyyy HH:mm').format(f.fecha)} - \$${f.total.toStringAsFixed(0)}',
                          ),
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
                        );
                      },
                    ),
                  ),
                  if (hayMas)
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            limiteFacturas += 20;
                          });
                        },
                        child: const Text('Ver más facturas'),
                      ),
                    ),
                ],
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
                    await ventasProvider.cargarDatos(); // Recarga todos los datos

                    Navigator.pop(context); // Cierra el diálogo

                    //Reemplaza la pantalla para actualizar datos en pantalla
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleCargueScreen(cargue: nuevoCargue),
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Factura(s) añadida(s) correctamente')),
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