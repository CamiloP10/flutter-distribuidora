import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';

// Importaciones para el pdf
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/cargue.dart'; // Tu modelo de Cargue
import '../utils/pdf_generator.dart';
import 'detalle_cargue_screen.dart';

import 'package:provider/provider.dart'; // Soluciona: Undefined name 'Provider'
import '../providers/ventas_provider.dart'; // Soluciona: The name 'VentasProvider' isn't a type
import '../models/factura.dart'; // Soluciona: The name 'Factura' isn't a type

import '../providers/cliente_provider.dart';

class DetalleLiquidacionScreen extends StatelessWidget {
  final Map<String, dynamic> liquidacion;

  const DetalleLiquidacionScreen({super.key, required this.liquidacion});



  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final fechaRaw = liquidacion['fecha'];
    final fechaDt = DateTime.parse(fechaRaw);
    final desglose = jsonDecode(liquidacion['desgloseBilletes'] ?? '{}');

    // Lógica de cálculos (se mantiene igual)

    // Lógica de cálculos con protección de tipos
    final double totalVendido = (liquidacion['totalFinal'] as num?)?.toDouble() ?? 0.0;
    final double nequi = (liquidacion['totalNequi'] as num?)?.toDouble() ?? 0.0;
    final double creditosNuevos = (liquidacion['totalCreditosNuevos'] as num?)?.toDouble() ?? 0.0;
    final double devoluciones = (liquidacion['totalDevoluciones'] as num?)?.toDouble() ?? 0.0;
    final double recaudos = (liquidacion['totalCreditosAntiguos'] as num?)?.toDouble() ?? 0.0;
    final double recibidoTotal = (liquidacion['totalEfectivo'] as num?)?.toDouble() ?? 0.0;
    final double esperado = totalVendido - nequi - creditosNuevos - devoluciones + recaudos;
    final double diferencia = recibidoTotal - esperado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Liquidación'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ID Y FECHA (Encabezado)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liquidación #${liquidacion['id']}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy  -  hh:mm a').format(fechaDt),
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                    ),
                  ],
                ),
                const Icon(Icons.receipt_long, size: 40, color: Colors.blueGrey),
              ],
            ),

            const SizedBox(height: 20),

            // 2. BOTÓN DE PDF (Acción inmediata)
            ElevatedButton.icon(
              onPressed: () => _generarCompartirPDF(context),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('GENERAR / COMPARTIR PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            const SizedBox(height: 25),

            // 3. RESTO DE LA INFORMACIÓN
            _buildCardSeccion('Resumen de Cuentas', [
              _fila('Total Vendido (Facturas)', totalVendido, f, bold: true),
              _fila('Devoluciones', devoluciones, f, color: Colors.orange),
              _fila('Créditos (Nuevos)', creditosNuevos, f, color: Colors.red),
              _fila('Nequi (Virtual)', nequi, f, color: Colors.blue),
              _fila('Anteriores Créditos', recaudos, f, color: Colors.green),
            ]),

            const SizedBox(height: 15),

            _buildCardSeccion('Balance de Efectivo', [
              _fila('Efectivo Esperado', esperado, f, bold: true),
              _fila('Efectivo Recibido', recibidoTotal, f, color: Colors.teal),
              const Divider(),
              _fila(
                diferencia >= 0 ? 'Diferencia (A FAVOR)' : 'Diferencia (FALTANTE)',
                diferencia,
                f,
                bold: true,
                color: diferencia >= 0 ? Colors.green : Colors.red,
              ),
            ]),

            const SizedBox(height: 20),
            const Text('Cargues Vinculados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildListaCargues(liquidacion['id']),

            const SizedBox(height: 20),
            _buildExpansionBilletes(desglose, f),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE APOYO ---
  Widget _buildCardSeccion(String titulo, List<Widget> hijos) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, double valor, NumberFormat f, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            f.format(valor),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaCargues(int id) {
    final f = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DBHelper.obtenerCarguesPorLiquidacion(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("No hay cargues vinculados");
        }

        return Column(
          children: snapshot.data!.map((c) {
            final double totalCargue = (c['totalCargue'] as num?)?.toDouble() ?? 0.0;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.blueGrey),
                title: Text('Cargue #${c['id']}'),
                subtitle: Text('${c['conductor']}'),
                // Muestra el total del cargue a la derecha
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.format(totalCargue),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  // 1. Convertir el String "1,2,3" en una lista de Integers [1, 2, 3]
                  List<int> listaIds = [];
                  if (c['idsDeFacturas'] != null && c['idsDeFacturas'].toString().isNotEmpty) {
                    listaIds = c['idsDeFacturas']
                        .toString()
                        .split(',')
                        .map((id) => int.parse(id))
                        .toList();
                  }

                  // 2. Crear el objeto con los datos reales
                  final objetoCargue = Cargue(
                    id: c['id'],
                    vehiculoAsignado: c['vehiculo'] ?? '',
                    conductor: c['conductor'] ?? '',
                    fecha: DateTime.parse(c['fecha']),
                    facturaIds: listaIds, // <--- ¡AHORA YA NO VA VACÍO!
                    observaciones: c['observaciones'] ?? '',
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetalleCargueScreen(cargue: objetoCargue),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildExpansionBilletes(dynamic desglose, NumberFormat f) {
    final billetes = Map<String, dynamic>.from(desglose['billetes'] ?? {});
    return ExpansionTile(
      title: const Text('Ver Arqueo de Billetes / Monedas'),
      children: [
        ...billetes.entries.where((e) => e.value > 0).map((e) =>
            ListTile(title: Text('Denominación ${e.key}'), trailing: Text('Cant: ${e.value}'))
        ),
        ListTile(
          title: const Text('Total en Monedas', style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Text(f.format(desglose['total_monedas'] ?? 0)),
        )
      ],
    );
  }

  Future<void> _generarCompartirPDF(BuildContext context) async {
    try {
      final DateTime fechaOriginal = DateTime.parse(liquidacion['fecha']);
      final int idLiquidacion = liquidacion['id'];

      // 1. Obtener los cargues vinculados
      final List<Map<String, dynamic>> carguesMap =
      await DBHelper.obtenerCarguesPorLiquidacion(idLiquidacion);

      // 2. Recolectar todos los IDs de facturas para buscarlas en la DB
      List<int> todosLosIdsFacturas = [];

      List<Cargue> carguesList = carguesMap.map((map) {
        List<int> ids = [];
        if (map['idsDeFacturas'] != null && map['idsDeFacturas'].toString().isNotEmpty) {
          ids = map['idsDeFacturas'].toString().split(',').map((e) => int.parse(e)).toList();
          todosLosIdsFacturas.addAll(ids); // Agregamos a la lista global de búsqueda
        }

        return Cargue(
          id: map['id'],
          vehiculoAsignado: map['vehiculo'] ?? '',
          conductor: map['conductor'] ?? '',
          fecha: DateTime.parse(map['fecha']),
          facturaIds: ids,
          observaciones: map['observaciones'] ?? '',
        );
      }).toList();

      // 3. BUSCAR LAS FACTURAS REALES (Esto quita los ceros en los cargues del PDF)
      // Usamos el provider para obtener todas y filtramos, o una consulta al DBHelper
      final ventasProvider = Provider.of<VentasProvider>(context, listen: false);
      List<Factura> facturasParaPDF = ventasProvider.facturas
          .where((f) => todosLosIdsFacturas.contains(f.id))
          .toList();

      final desglose = jsonDecode(liquidacion['desgloseBilletes'] ?? '{}');
      final Map<String, int> cantidadesMap = Map<String, int>.from(desglose['billetes'] ?? {});

      final Map<String, double> subtotalesCalculados = {
        '100k': (cantidadesMap['100k'] ?? 0) * 100000.0,
        '50k': (cantidadesMap['50k'] ?? 0) * 50000.0,
        '20k': (cantidadesMap['20k'] ?? 0) * 20000.0,
        '10k': (cantidadesMap['10k'] ?? 0) * 10000.0,
        '5k': (cantidadesMap['5k'] ?? 0) * 5000.0,
        '2k': (cantidadesMap['2k'] ?? 0) * 2000.0,
      };

      // NUEVO: Obtener los clientes para poder ver los nombres en el PDF
      final clientesProvider = Provider.of<ClienteProvider>(context, listen: false);
      final listaClientes = clientesProvider.clientes;

      // 4. Generar el PDF pasando ID, FECHA y FACTURAS
      final pdfBytes = await PdfGenerator.generarLiquidacionPDF(
        liquidacionId: idLiquidacion,    // <-- Nuevo parámetro
        fechaManual: fechaOriginal,     // <-- Nuevo parámetro
        totalVendido: (liquidacion['totalFinal'] as num).toDouble(),
        totalDevoluciones: (liquidacion['totalDevoluciones'] as num).toDouble(),
        totalCreditos: (liquidacion['totalCreditosNuevos'] as num).toDouble(),
        totalNequi: (liquidacion['totalNequi'] as num).toDouble(),
        totalRecaudoCreditos: (liquidacion['totalCreditosAntiguos'] as num).toDouble(),
        totalRecibido: (liquidacion['totalEfectivo'] as num).toDouble(),
        cantidades: cantidadesMap,
        subtotales: subtotalesCalculados,
        monedas: (desglose['total_monedas'] as num).toDouble(),
        carguesLiquidados: carguesList,
        todasLasFacturas: facturasParaPDF, // <-- YA NO ESTÁ VACÍO
        todosLosClientes: listaClientes,
      );

      // 5. Guardar y compartir
      final String nombreArchivo = "Liquidacion_$idLiquidacion.pdf";
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$nombreArchivo');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Liquidación #$idLiquidacion - Generada el ${DateFormat('dd/MM/yyyy').format(fechaOriginal)}',
      );
    } catch (e) {
      debugPrint("Error al generar PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    }
  }
}