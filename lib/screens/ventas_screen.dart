import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/factura.dart';
import '../models/detalle_factura.dart';
import '../models/producto.dart';
import '../models/cliente.dart';
import 'package:intl/intl.dart';

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
          return ExpansionTile(
            title: Text('Factura #${f.id} - \$${currencyFormat.format(f.total)}'),
            subtitle: Text(
              '${cliente?.nombre ?? 'Cliente eliminado'} - ${DateFormat('dd/MM/yyyy').format(f.fecha)}',
            ),
            children: [
              ListTile(
                title: Text('Estado: ${f.estadoPago}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pagado: \$${currencyFormat.format(f.pagado)}'),
                    Text('Saldo: \$${currencyFormat.format(f.saldoPendiente)}'),
                    Text('Tipo de Pago: ${f.tipoPago}'),
                    if (f.informacion.isNotEmpty) Text('Observaciones: ${f.informacion}'),
                  ],
                ),
              ),
              const Divider(),
              ...?detallesMap[f.id]?.map((d) {
                final producto = productosMap[d.productoId];
                return ListTile(
                  title: Text('${producto?.nombre ?? 'Producto eliminado'} - ${producto?.presentacion ?? ''}'),
                  subtitle: Text('Cantidad: ${d.cantidad}, Precio: \$${currencyFormat.format(d.precioModificado)}'),
                  trailing: Text('Subtotal: \$${currencyFormat.format(d.subtotal)}'),
                );
              }).toList(),
              const Divider(),
            ],
          );
        },
      ),
    );
  }
}
