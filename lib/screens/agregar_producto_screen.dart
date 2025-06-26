import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/producto.dart';
import '../providers/producto_provider.dart';

class AgregarProductoScreen extends StatefulWidget {
  const AgregarProductoScreen({super.key});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController presentacionController = TextEditingController();
  final TextEditingController cantidadController = TextEditingController();
  final TextEditingController precioController = TextEditingController();

  void guardarProducto() async {
    final producto = Producto(
      codigo: 'P${DateTime.now().millisecondsSinceEpoch}', // ID único
      nombre: nombreController.text,
      presentacion: presentacionController.text,
      cantidad: double.tryParse(cantidadController.text) ?? 0,
      precio: double.tryParse(precioController.text) ?? 0.0,
    );

    await context.read<ProductoProvider>().agregarProducto(producto);
    Navigator.pop(context, true); // Regresa a pantalla anterior con éxito
  }

  @override
  Widget build(BuildContext context) {
    final productos = context.watch<ProductoProvider>().productos;
    final nombresUnicos = productos.map((p) => p.nombre).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Producto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: nombreController.text.isNotEmpty ? nombreController.text : null,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: nombresUnicos.map((nombre) {
                return DropdownMenuItem(
                  value: nombre,
                  child: Text(nombre),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  nombreController.text = value ?? '';
                });
              },
            ),
            TextField(
              controller: presentacionController,
              decoration: const InputDecoration(labelText: 'Producto'),
            ),
            TextField(
              controller: cantidadController,
              decoration: const InputDecoration(labelText: 'Cantidad'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: precioController,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: guardarProducto,
              child: const Text('Guardar Producto'),
            ),
          ],
        ),
      ),
    );
  }
}