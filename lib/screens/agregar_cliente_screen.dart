import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cliente.dart';
import '../providers/cliente_provider.dart';

class AgregarClienteScreen extends StatefulWidget {
  const AgregarClienteScreen({super.key});

  @override
  State<AgregarClienteScreen> createState() => _AgregarClienteScreenState();
}

class _AgregarClienteScreenState extends State<AgregarClienteScreen> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController informacionController = TextEditingController();

  void guardarCliente() async {
    final cliente = Cliente(
      id: 0, // será ignorado si es autoincremental en la base de datos
      nombre: nombreController.text,
      telefono: telefonoController.text,
      informacion: informacionController.text,
    );

    await context.read<ClienteProvider>().agregarCliente(cliente);
    Navigator.pop(context, true); // Regresa con éxito
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Cliente')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: telefonoController,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: informacionController,
              decoration: const InputDecoration(labelText: 'Información adicional'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: guardarCliente,
              child: const Text('Guardar Cliente'),
            ),
          ],
        ),
      ),
    );
  }
}

