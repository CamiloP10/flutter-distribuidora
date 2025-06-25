/*import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/factura.dart';
import '../models/detalle_factura.dart';
import '../models/producto.dart';
import '../models/cliente.dart';
import 'detalle_venta_screen.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'es_CO');
  List<Factura> facturas = [];
  Map<int, List<DetalleFactura>> detallesMap = {};
  Map<int, Producto> productosMap = {};
  Map<int, Cliente> clientesMap = {};

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    final fcts = await DBHelper.obtenerFacturas();
    final productos = await DBHelper.obtenerProductos();
    final clientes = await DBHelper.obtenerClientes();

    final Map<int, Producto> prodMap = {
      for (var p in productos) p.id!: p
    };
    final Map<int, Cliente> cliMap = {
      for (var c in clientes) c.id!: c
    };

    final Map<int, List<DetalleFactura>> dMap = {};
    for (var f in fcts) {
      final detalles = await DBHelper.obtenerDetallesFactura(f.id!);
      dMap[f.id!] = detalles;
    }

    setState(() {
      facturas = fcts;
      productosMap = prodMap;
      clientesMap = cliMap;
      detallesMap = dMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Ventas')),
      body: ListView.builder(
        itemCount: facturas.length,
        itemBuilder: (context, index) {
          final f = facturas[index];
          final cliente = clientesMap[f.clienteId];
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
                    detalles: detallesMap[f.id] ?? [],
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
}*/

// con providers
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/ventas_provider.dart';
import '../screens/detalle_venta_screen.dart';
import '../models/factura.dart';
import '../models/cliente.dart';
import '../models/producto.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'es_CO');

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

    final facturas = ventasProvider.facturas;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Ventas')),
      body: ListView.builder(
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
    );
  }
}


