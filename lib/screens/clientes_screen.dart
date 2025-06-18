import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cliente.dart';
import '../providers/cliente_provider.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController busquedaController = TextEditingController();
  List<Cliente> clientesFiltrados = [];
  bool _cargando = true; // <- Añadido

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<ClienteProvider>(context, listen: false);
      await provider.cargarClientes();
      setState(() {
        _cargando = false; // <- solo después de cargar
      });
    });
  }

  void filtrarClientes(String query, List<Cliente> clientes) {
    final buscar = query.toLowerCase();
    final filtrados = clientes.where((c) {
      final nombre = c.nombre.toLowerCase();
      final info = c.informacion.toLowerCase();
      return nombre.contains(buscar) || info.contains(buscar);
    }).toList();

    setState(() {
      clientesFiltrados = filtrados;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clienteProvider = Provider.of<ClienteProvider>(context);
    final clientes = clienteProvider.clientes;
    final mostrar = busquedaController.text.isEmpty ? clientes : clientesFiltrados;

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Clientes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: busquedaController,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o información',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (query) => filtrarClientes(query, clientes),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : clientes.isEmpty
                  ? const Center(child: Text('No hay clientes disponibles.'))
                  : mostrar.isEmpty
                  ? const Center(child: Text('No hay clientes que coincidan.'))
                  : ListView.builder(
                itemCount: mostrar.length,
                itemBuilder: (context, index) {
                  final c = mostrar[index];
                  return ListTile(
                    title: Text(c.nombre),
                    subtitle: Text('tel: ${c.telefono} - ${c.informacion}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/agregarCliente');
          if (result == true) {
            await clienteProvider.cargarClientes();
            if (busquedaController.text.isNotEmpty) {
              filtrarClientes(busquedaController.text, clienteProvider.clientes);
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}



