import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cargue.dart';
import '../providers/ventas_provider.dart';
import '../providers/cliente_provider.dart';
import '../models/cliente.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../db/db_helper.dart';
import '../utils/pdf_generator.dart';
import 'package:share_plus/share_plus.dart';

int generarIdCortoUnico() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final idStr = timestamp.toString().substring(timestamp.toString().length - 8);
  return int.parse(idStr);
}

class CargueScreen extends StatefulWidget {
  const CargueScreen({super.key});

  @override
  State<CargueScreen> createState() => _CargueScreenState();
}

class _CargueScreenState extends State<CargueScreen> {
  String vehiculoAsignado = '';
  int _limiteFacturas = 20;
  final Set<int> facturasSeleccionadas = {};
  final TextEditingController _conductorController = TextEditingController();
  final TextEditingController _observacionController = TextEditingController();
  bool _botonDeshabilitado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ventasProvider = Provider.of<VentasProvider>(context, listen: false);
      ventasProvider.cargarDatos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ventasProvider = Provider.of<VentasProvider>(context);
    final todasLasFacturas = [...ventasProvider.facturas]..sort((a, b) => b.fecha.compareTo(a.fecha));
    final facturas = todasLasFacturas.take(_limiteFacturas).toList();
    final hayMasFacturas = todasLasFacturas.length > facturas.length;
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
                    subtitle: Text("${factura.fecha.toString().substring(0, 16)} - Total: \$${factura.total.toStringAsFixed(0)}"),
                  );
                },
              ),
            ),
            if (hayMasFacturas)
              TextButton(
                onPressed: () {
                  setState(() {
                    _limiteFacturas += 20;
                  });
                },
                child: const Text("Ver más facturas"),
              ),
            ElevatedButton.icon(
              onPressed: vehiculoAsignado.isNotEmpty && facturasSeleccionadas.isNotEmpty && !_botonDeshabilitado
                  ? () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setStateDialog) => AlertDialog(
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
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Cancelar"),
                          ),
                          ElevatedButton(
                            onPressed: _botonDeshabilitado
                                ? null
                                : () async {
                              setStateDialog(() => _botonDeshabilitado = true);

                              final conductor = _conductorController.text.trim();
                              if (conductor.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("El nombre del conductor es obligatorio")),
                                );
                                setStateDialog(() => _botonDeshabilitado = false);
                                return;
                              }

                              final nuevoCargue = Cargue(
                                id: generarIdCortoUnico(),
                                vehiculoAsignado: vehiculoAsignado,
                                fecha: DateTime.now(),
                                facturaIds: facturasSeleccionadas.toList(),
                                conductor: conductor,
                                observaciones: _observacionController.text.trim(),
                              );

                              try {
                                await DBHelper.insertarCargue(nuevoCargue);

                                final clienteProvider = Provider.of<ClienteProvider>(context, listen: false);
                                final pdfBytes = await PdfGenerator.generarCarguePDF(
                                  cargue: nuevoCargue,
                                  facturas: ventasProvider.facturas,
                                  detalles: ventasProvider.getAllDetalles(),
                                  productos: ventasProvider.productosMap.values.toList(),
                                  clientes: clienteProvider.clientesMap,
                                );

                                final outputDir = await getTemporaryDirectory();
                                final file = File("${outputDir.path}/cargue_\${nuevoCargue.id}.pdf");
                                await file.writeAsBytes(pdfBytes);
                                await Share.shareXFiles([
                                  XFile(file.path)
                                ], text: 'Cargue #\${nuevoCargue.id}');

                                if (mounted) {
                                  Navigator.of(context).pop();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Cargue generado y compartido con éxito")),
                                  );
                                }
                              } catch (e) {
                                setStateDialog(() => _botonDeshabilitado = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error al guardar el cargue: \$e")),
                                );
                              }
                            },
                            child: _botonDeshabilitado
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Text("Confirmar"),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
                  : null,
              icon: const Icon(Icons.fire_truck),
              label: const Text("Generar Cargue"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}