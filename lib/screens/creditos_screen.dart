import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/ventas_provider.dart';
import '../providers/cliente_provider.dart';
import '../providers/producto_provider.dart';
import '../models/cliente.dart';
import '../models/factura.dart';
import '../models/producto.dart';
import 'detalle_venta_screen.dart';
import '../screens/historial_abonos_screen.dart';

class CreditosScreen extends StatelessWidget {
  const CreditosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ventasProvider = Provider.of<VentasProvider>(context);
    final clienteProvider = Provider.of<ClienteProvider>(context);
    final productoProvider = Provider.of<ProductoProvider>(context);

    // Obtener solo facturas en crédito
    final List<Factura> creditos = ventasProvider.facturas
        .where((f) => f.estadoPago.toLowerCase().trim() == 'crédito')
        .toList();

    // Ordenar por fecha (antiguos primero)
    creditos.sort((a, b) => a.fecha.compareTo(b.fecha));

    final format = DateFormat('dd/MM/yyyy');
    final currency = NumberFormat('#,##0', 'es_CO');
    final hoy = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos Pendientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver historial de abonos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistorialAbonosScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: creditos.isEmpty
          ? const Center(child: Text('No hay créditos pendientes.'))
          : ListView.builder(
        itemCount: creditos.length,
        itemBuilder: (context, index) {
          final f = creditos[index];
          final Cliente? cliente = clienteProvider.clientesMap[f.clienteId ?? 0];
          final dias = hoy.difference(f.fecha).inDays;
          final Map<int, Producto> productosMap = productoProvider.productosMap;

          return ListTile(
            title: Text('Factura #${f.id} - ${cliente?.nombre ?? 'NR'}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fecha: ${format.format(f.fecha)}'),
                Row(
                  children: [
                    Text(
                      'Días transcurridos: $dias días',
                      style: TextStyle(
                        color: dias < 4
                            ? Colors.green
                            : dias < 8
                            ? Colors.orange
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (dias >= 15)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.warning, color: Colors.red, size: 18),
                      ),
                  ],
                ),
                Text('Saldo: \$${currency.format(f.saldoPendiente)}'),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            isThreeLine: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleVentaScreen(
                    factura: f,
                    cliente: cliente,
                    productosMap: productosMap,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}