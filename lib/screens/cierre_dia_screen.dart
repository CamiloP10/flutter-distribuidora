import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cierre_dia_provider.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Cierre del Día')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFechaSelector(context, provider),
          const SizedBox(height: 16),
          _buildResumenCard('Total de Facturas', provider.totalFacturas.toString(), Icons.receipt_long),
          _buildResumenCard('Total Recibido', '\$${provider.totalPagado.toStringAsFixed(0)}', Icons.attach_money),
          _buildResumenCard('Total Créditos', '\$${provider.totalCredito.toStringAsFixed(0)}', Icons.credit_card),
          _buildResumenCard('Total Venta del Día', '\$${provider.totalVentas.toStringAsFixed(0)}', Icons.bar_chart),
          const Divider(height: 32, thickness: 1),
          _buildResumenCard('Abonos a Créditos Anteriores', '\$${provider.totalAbonosDelDia.toStringAsFixed(0)}', Icons.account_balance_wallet),
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
