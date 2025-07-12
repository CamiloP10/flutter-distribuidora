import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cierre_dia_provider.dart';
import '../utils/pdf_generator.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class CierreDiaScreen extends StatefulWidget {
  const CierreDiaScreen({super.key});

  @override
  State<CierreDiaScreen> createState() => _CierreDiaScreenState();
}

class _CierreDiaScreenState extends State<CierreDiaScreen> {
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<CierreDiaProvider>(context, listen: false);
    provider.cargarResumenDelDia();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CierreDiaProvider>(context);
    final currencyFormat = NumberFormat('#,##0', 'es_CO');

    return Scaffold(
      appBar: AppBar(title: const Text('Cierre del Día')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFechaSelector(context, provider),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generar PDF'),
            onPressed: () async {
              final detalleFacturas = provider.facturasDelDia.map((f) {
                return {
                  'id': f.id,
                  'cliente': provider.nombresClientes[f.clienteId] ?? 'No registrado',
                  'total': f.total ?? 0,
                };
              }).toList();

              final pdf = await PdfGenerator.generarCierreDiaPDF(
                fecha: provider.fechaSeleccionada,
                totalFacturas: provider.totalFacturas,
                totalPagado: provider.totalPagado,
                totalCredito: provider.totalCredito,
                totalVentas: provider.totalVentas,
                totalAbonos: provider.totalAbonosDelDia,
                detalleFacturas: detalleFacturas,
                abonosDetallados: provider.abonosDetallados,
              );

              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/cierre_${provider.fechaSeleccionada.toIso8601String().substring(0, 10)}.pdf');
              await file.writeAsBytes(pdf);

              await Share.shareXFiles(
                [XFile(file.path)],
                text: 'Cierre del día ${provider.fechaSeleccionada.day}/${provider.fechaSeleccionada.month}',
              );
            },
          ),
          const SizedBox(height: 16),

          ExpansionTile(
            leading: const Icon(Icons.receipt_long, color: Colors.teal),
            title: const Text(
              'Total de Facturas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${provider.totalFacturas} facturas'),
            children: provider.facturasDelDia.isEmpty
                ? [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No hay facturas registradas en esta fecha.'),
              )
            ]
                : provider.facturasDelDia.map((f) {
              final cliente = provider.nombresClientes[f.clienteId] ?? 'No registrado';
              final monto = currencyFormat.format(f.total ?? 0);

              return ListTile(
                title: Text('Fact #${f.id} - $cliente'),
                trailing: Text('\$$monto'),
              );
            }).toList(),
          ),
          _buildResumenCard('Total Recibido', '\$${currencyFormat.format(provider.totalPagado)}', Icons.attach_money),
          _buildResumenCard('Total Créditos', '\$${currencyFormat.format(provider.totalCredito)}', Icons.credit_card),
          _buildResumenCard('Total Venta del Día', '\$${currencyFormat.format(provider.totalVentas)}', Icons.bar_chart),
          const Divider(height: 32, thickness: 1.5),
          ExpansionTile(
            leading: const Icon(Icons.account_balance_wallet, color: Colors.teal),
            title: const Text(
              'Abonos a Créditos Anteriores',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('\$${currencyFormat.format(provider.totalAbonosDelDia)}'),
            children: provider.abonosDetallados.isEmpty
                ? [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No se registraron abonos a créditos anteriores.'),
              )
            ]
                : provider.abonosDetallados.map((ab) {
              return ListTile(
                title: Text('Fact #${ab['facturaId']} - ${ab['cliente']}'),
                trailing: Text(
                  '\$${currencyFormat.format(ab['monto'])}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard(String titulo, String valor, IconData icono) {
    return Card(
      child: ListTile(
        leading: Icon(icono, color: Colors.teal),
        title: Text(titulo),
        trailing: Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildFechaSelector(BuildContext context, CierreDiaProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Fecha: ${provider.fechaSeleccionada.day}/${provider.fechaSeleccionada.month}/${provider.fechaSeleccionada.year}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final nuevaFecha = await showDatePicker(
              context: context,
              initialDate: provider.fechaSeleccionada,
              firstDate: DateTime(2023),
              lastDate: DateTime.now(),
            );
            if (nuevaFecha != null) {
              provider.cambiarFecha(nuevaFecha);
            }
          },
          icon: const Icon(Icons.calendar_today),
          label: const Text('Cambiar'),
        ),
      ],
    );
  }
}