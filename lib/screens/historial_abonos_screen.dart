import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/abono.dart';
import '../models/factura.dart';
import '../models/cliente.dart';

class HistorialAbonosScreen extends StatefulWidget {
  const HistorialAbonosScreen({super.key});

  @override
  State<HistorialAbonosScreen> createState() => _HistorialAbonosScreenState();
}

class _HistorialAbonosScreenState extends State<HistorialAbonosScreen> {
  List<Abono> abonos = [];
  Map<int, Factura> facturasMap = {};
  Map<int, Cliente> clientesMap = {};
  bool cargando = true;

  final currency = NumberFormat('#,##0', 'es_CO');
  final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    cargarAbonos();
  }

  Future<void> cargarAbonos() async {
    final todasFacturas = await DBHelper.obtenerFacturas();
    final todosClientes = await DBHelper.obtenerClientes();
    final todosAbonos = await DBHelper.obtenerTodosLosAbonos();

    // Mapa de ID -> Factura y Cliente
    facturasMap = {for (var f in todasFacturas) f.id!: f};
    clientesMap = {for (var c in todosClientes) c.id!: c};

    todosAbonos.sort((a, b) => b.fecha.compareTo(a.fecha)); // más recientes primero

    setState(() {
      abonos = todosAbonos;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Abonos')),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : abonos.isEmpty
          ? const Center(child: Text('No hay abonos registrados.'))
          : ListView.builder(
        itemCount: abonos.length,
        itemBuilder: (_, index) {
          final abono = abonos[index];
          final factura = facturasMap[abono.facturaId];
          final cliente = clientesMap[factura?.clienteId ?? 0];

          return ListTile(
            leading: const Icon(Icons.payments),
            title: Text(
              'Fact #${abono.facturaId} - ${cliente?.nombre ?? 'Cliente no encontrado'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Fecha: ${formatoFecha.format(abono.fecha)}\nMonto: \$${currency.format(abono.monto)}',
            ),
          );
        },
      ),
    );
  }
}
