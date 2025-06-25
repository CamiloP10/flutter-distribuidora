import 'package:flutter/material.dart';
import 'inventario_screen.dart';
import 'clientes_screen.dart';
import 'factura_screen.dart';
import 'ventas_screen.dart';
import '../db/db_helper.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import 'factura_screen.dart';
import 'cargue_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('DISTRIBUIDORA  LA BELLEZA',
        style: TextStyle(color: Colors.white54), )
        , backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // prueba icon para crear facturas
            ElevatedButton.icon(
              onPressed: () async {
                final clientes = await DBHelper.obtenerClientes();
                final productos = await DBHelper.obtenerProductos();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => FacturaScreen(
                        clientes: clientes,
                        productos: productos,
                      )
                  ),
                );
              },
              icon: Icon(Icons.receipt_long),
              label: Text('Crear Factura'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),

            ElevatedButton.icon( // para ventas
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VentasScreen()),
                );
              },
              icon: Icon(Icons.shopify),
              label: Text('Ventas'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),

            ElevatedButton.icon( // para inventario
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InventarioScreen()),
                );
              },
              icon: Icon(Icons.inventory),
              label: Text('Inventario'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),


            ElevatedButton.icon(//para clientes
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ClientesScreen()),
                );
              },
              icon: Icon(Icons.people),
              label: Text('Clientes'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),


            ElevatedButton.icon( // para cargues
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CargueScreen()),
                );
              },
              icon: Icon(Icons.fire_truck),
              label: Text('Asignar Cargue'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

