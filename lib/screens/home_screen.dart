import 'package:flutter/material.dart';
import 'inventario_screen.dart';
import 'clientes_screen.dart';
import 'factura_screen.dart';
import 'ventas_screen.dart';
import 'cargue_screen.dart';
import 'cargue_historial_screen.dart';
import 'cierre_dia_screen.dart';
import 'liquidacion_cargue_screen.dart';
//import '../db/db_helper.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DISTRIBUIDORA  LA BELLEZA',
          style: TextStyle(color: Colors.white54),
        ),
        backgroundColor: Colors.black,
      ),
      // --- CAMBIO AQUÍ ---
      // 1. Reemplazamos el 'Padding' y 'Column' por un 'ListView'.
      // 2. Movimos el padding de 'Padding' al 'ListView' usando la propiedad 'padding'.
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),

          // LOGO
          Image.asset(
            'assets/icon.png', // ruta del logo
            height: 130,
          ),
          const SizedBox(height: 20),

          // BOTONES
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FacturaScreen()),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Crear Factura'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VentasScreen()),
              );
            },
            icon: const Icon(Icons.shopify),
            label: const Text('Ventas'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InventarioScreen()),
              );
            },
            icon: const Icon(Icons.inventory),
            label: const Text('Inventario'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ClientesScreen()),
              );
            },
            icon: const Icon(Icons.people),
            label: const Text('Clientes'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CargueScreen()),
              );
            },
            icon: const Icon(Icons.fire_truck),
            label: const Text('Asignar Cargue'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CargueHistorialScreen()),
              );
            },
            icon: const Icon(Icons.delivery_dining),
            label: const Text('Historial Cargues'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LiquidacionCargueScreen()),
              );
            },
            icon: const Icon(Icons.request_quote),
            label: const Text('Liquidación Cargues'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CierreDiaScreen()),
              );
            },
            icon: const Icon(Icons.checklist_rounded),
            label: const Text('Cierre del Día'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),

          /*ElevatedButton.icon( // boton para pruebas
              onPressed: () async {
                final db = await DBHelper.initDb();
                final tablas = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
                print('🔍 Tablas en la base de datos:');
                for (var t in tablas) {
                  print('📁 ${t['name']}');
                }
              },
              icon: Icon(Icons.search),
              label: Text('Verificar Tablas de datos DB'),
            ),*/
        ],
      ),
    );
  }
}