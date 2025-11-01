import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/producto.dart';
import '../providers/producto_provider.dart';
import '../providers/ventas_provider.dart';
import 'agregar_producto_screen.dart';

final NumberFormat currencyFormat = NumberFormat('#,##0', 'es_CO');

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final TextEditingController busquedaController = TextEditingController();
  List<Producto> productosFiltrados = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProductoProvider>(context, listen: false);
      provider.cargarProductos();
    });
  }

  void filtrarProductos(String query, List<Producto> productos) {
    final filtrados = productos.where((p) {
      final nombre = p.nombre.toLowerCase();
      final presentacion = p.presentacion.toLowerCase();
      final buscar = query.toLowerCase();
      return nombre.contains(buscar) || presentacion.contains(buscar);
    }).toList();

    setState(() {
      productosFiltrados = filtrados;
    });
  }

  @override
  Widget build(BuildContext context) {
    final productoProvider = Provider.of<ProductoProvider>(context);
    final productos = productoProvider.productos;

    final mostrar = busquedaController.text.isEmpty
        ? productos
        : productosFiltrados;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventario de Productos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: busquedaController,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o presentación',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (query) => filtrarProductos(query, productos),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: productos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : mostrar.isEmpty
                  ? const Center(child: Text('No hay productos que coincidan.'))
                  : ListView.builder(
                itemCount: mostrar.length,
                itemBuilder: (context, index) {
                  final p = mostrar[index];
                  return ListTile(
                    title: Text(
                      '${p.presentacion} - \$${currencyFormat.format(p.precio.toInt())}',
                    ),
                    subtitle: Text('${p.nombre} - Cod: ${p.codigo}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AgregarProductoScreen(producto: p),
                          ),
                        );

                        if (result == true) {
                          await productoProvider.cargarProductos();
                          await Provider.of<VentasProvider>(
                            context,
                            listen: false,
                          ).cargarProductos(); // sincroniza ventas
                          if (busquedaController.text.isNotEmpty) {
                            filtrarProductos(
                              busquedaController.text,
                              productoProvider.productos,
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/agregarProducto');
          if (result == true) {
            await productoProvider.cargarProductos();
            await Provider.of<VentasProvider>(
              context,
              listen: false,
            ).cargarProductos(); // sincroniza ventas
            if (busquedaController.text.isNotEmpty) {
              filtrarProductos(
                busquedaController.text,
                productoProvider.productos,
              );
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}