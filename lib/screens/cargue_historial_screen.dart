import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../models/cargue.dart';
import 'detalle_cargue_screen.dart';

class CargueHistorialScreen extends StatefulWidget {
  const CargueHistorialScreen({super.key});

  @override
  State<CargueHistorialScreen> createState() => _CargueHistorialScreenState();
}

class _CargueHistorialScreenState extends State<CargueHistorialScreen> {
  List<Cargue> cargues = [];

  @override
  void initState() {
    super.initState();
    cargarCargues();
  }

  Future<void> cargarCargues() async {
    final lista = await DBHelper.obtenerCargues();
    setState(() {
      cargues = lista;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Cargues')),
      body: cargues.isEmpty
          ? const Center(child: Text("No hay cargues registrados"))
          : ListView.builder(
        itemCount: cargues.length,
        itemBuilder: (context, index) {
          final cargue = cargues[index];
          return ListTile(
            title: Text("Cargue #${cargue.id} - ${cargue.vehiculoAsignado}"),
            subtitle: Text(
              "${DateFormat('dd/MM/yyyy HH:mm').format(cargue.fecha)} - ${cargue.conductor}",
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleCargueScreen(cargue: cargue),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
