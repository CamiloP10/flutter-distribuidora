import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/producto.dart';
import '../providers/producto_provider.dart';
import '../providers/ventas_provider.dart';

class AgregarProductoScreen extends StatefulWidget {
  final Producto? producto; // null si es nuevo

  const AgregarProductoScreen({super.key, this.producto});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController presentacionController = TextEditingController();
  final TextEditingController cantidadController = TextEditingController();
  final TextEditingController precioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.producto != null) {
      nombreController.text = widget.producto!.nombre;
      presentacionController.text = widget.producto!.presentacion;
      cantidadController.text = widget.producto!.cantidad.toInt().toString();
      precioController.text = widget.producto!.precio.toInt().toString();
    }
  }

  Future<void> guardarProducto() async {
    final producto = Producto(
      id: widget.producto?.id, // conservar el ID si se está editando
      codigo: widget.producto?.codigo ?? 'P${DateTime.now().millisecondsSinceEpoch}',
      nombre: nombreController.text,
      presentacion: presentacionController.text,
      cantidad: double.tryParse(cantidadController.text) ?? 0,
      precio: double.tryParse(precioController.text) ?? 0.0,
    );

    final productoProvider = context.read<ProductoProvider>();
    final ventasProvider = context.read<VentasProvider>();

    if (widget.producto != null) {
      await productoProvider.actualizarProducto(producto);
    } else {
      await productoProvider.agregarProducto(producto);
    }

    // Sincronizar también en VentasProvider
    await ventasProvider.cargarProductos();

    Navigator.pop(context, true); // Regresa a pantalla anterior con éxito
  }

  @override
  Widget build(BuildContext context) {
    final productos = context.watch<ProductoProvider>().productos;
    final nombresUnicos = productos.map((p) => p.nombre).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.producto != null ? 'Editar Producto' : 'Agregar Producto'),
      ),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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