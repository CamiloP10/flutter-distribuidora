import 'package:flutter/material.dart';
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
}

