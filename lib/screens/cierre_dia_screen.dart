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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CierreDiaProvider>(context, listen: false).cargarResumenDelDia();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre del Día'),
        backgroundColor: Colors.teal,
      ),
      body: Consumer<CierreDiaProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.totalFacturas == 0) {
            return const Center(
              child: Text('No hay facturas registradas para hoy.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildResumenCard('Total de Facturas', provider.totalFacturas.toString(), Icons.receipt),
              _buildResumenCard('Total Efectivo', '\$${provider.totalEfectivo.toStringAsFixed(0)}', Icons.money),
              _buildResumenCard('Total Transferencia', '\$${provider.totalTransferencia.toStringAsFixed(0)}', Icons.account_balance),
              _buildResumenCard('Total Créditos Pendientes', '\$${provider.totalCredito.toStringAsFixed(0)}', Icons.credit_card),
              const Divider(),
              _buildResumenCard('Total Recaudado Hoy', '\$${provider.totalRecaudado.toStringAsFixed(0)}', Icons.attach_money),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResumenCard(String titulo, String valor, IconData icono) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: ListTile(
        leading: Icon(icono, color: Colors.teal),
        title: Text(titulo),
        trailing: Text(
          valor,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}