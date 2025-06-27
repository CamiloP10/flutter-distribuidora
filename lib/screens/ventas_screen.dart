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
  final TextEditingController _searchController = TextEditingController();
  String _estadoPagoSeleccionado = 'Todos';
  DateTimeRange? _rangoFechas;

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
          factura.estadoPago.toLowerCase().trim() ==
              _estadoPagoSeleccionado.toLowerCase().trim();

      final coincideFecha = _rangoFechas == null ||
          (factura.fecha.isAfter(_rangoFechas!.start.subtract(const Duration(days: 1))) &&
              factura.fecha.isBefore(_rangoFechas!.end.add(const Duration(days: 1))));

      return coincideBusqueda && coincideEstado && coincideFecha;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Ventas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 250,
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
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: _estadoPagoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['Todos', 'Pagado', 'Crédito']
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(_rangoFechas == null
                      ? 'Rango de fechas'
                      : '${DateFormat('dd/MM/yyyy').format(_rangoFechas!.start)} - ${DateFormat('dd/MM/yyyy').format(_rangoFechas!.end)}'),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 1),
                      initialDateRange: _rangoFechas,
                    );
                    if (picked != null) {
                      setState(() {
                        _rangoFechas = picked;
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Limpiar filtros',
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _estadoPagoSeleccionado = 'Todos';
                      _rangoFechas = null;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: facturas.isEmpty
                ? const Center(child: Text('No se encontraron resultados.'))
                : ListView.builder(
              itemCount: facturas.length,
              itemBuilder: (context, index) {
                final f = facturas[index];
                final Cliente? cliente = ventasProvider.getCliente(f.clienteId);
                final Map<int, Producto> productosMap = ventasProvider.productosMap;

                final esCredito = f.estadoPago.toLowerCase().contains('crédito');

                return ListTile(
                  title: Text(
                    'Factura #${f.id} - ${cliente?.nombre ?? 'Cliente NR'}',
                    style: TextStyle(
                      color: esCredito ? Colors.red : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy HH:mm').format(f.fecha)} - \$${currencyFormat.format(f.total)}',
                  ),
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