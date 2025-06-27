import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/ventas_provider.dart';
import '../screens/detalle_venta_screen.dart';
import '../models/cliente.dart';
import '../models/producto.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'es_CO');
  TextEditingController _searchController = TextEditingController();
  String _estadoPagoSeleccionado = 'Todos';

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

    if (ventasProvider.cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final facturas = ventasProvider.facturas.where((factura) {
      final cliente = ventasProvider.getCliente(factura.clienteId);
      final query = _searchController.text.toLowerCase();

      final coincideBusqueda = query.isEmpty ||
          factura.id.toString().contains(query) ||
          (cliente?.nombre.toLowerCase().contains(query) ?? false);

      final coincideEstado = _estadoPagoSeleccionado == 'Todos' ||
          factura.estadoPago == _estadoPagoSeleccionado;

      return coincideBusqueda && coincideEstado;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Ventas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por cliente o factura',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _estadoPagoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['Todos', 'Pagado', 'Pendiente']
                        .map((estado) => DropdownMenuItem(
                      value: estado,
                      child: Text(estado),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _estadoPagoSeleccionado = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: facturas.length,
              itemBuilder: (context, index) {
                final f = facturas[index];
                final Cliente? cliente = ventasProvider.getCliente(f.clienteId);
                final Map<int, Producto> productosMap = ventasProvider.productosMap;

                return ListTile(
                  title: Text('Factura #${f.id} - ${cliente?.nombre ?? 'Cliente NR'}'),
                  subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(f.fecha)} - \$${currencyFormat.format(f.total)}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleVentaScreen(
                          factura: f,
                          cliente: cliente,
                          detalles: ventasProvider.getDetalles(f.id!),
                          productosMap: productosMap,
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
    );
  }
}