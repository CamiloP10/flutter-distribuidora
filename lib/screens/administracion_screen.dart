import 'package:flutter/material.dart';
import 'inventario_screen.dart';
import 'clientes_screen.dart';
import 'cierre_dia_screen.dart';
import 'calculadora_efectivo_screen.dart'; // <--- 1. Importa la nueva pantalla
import '../db/db_helper.dart';

class AdministracionScreen extends StatelessWidget {
  const AdministracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración', style: TextStyle(color: Colors.white54)),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Gestión de Datos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _itemAdmin(context, 'Editar Productos', Icons.inventory, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const InventarioScreen()));
          }),
          _itemAdmin(context, 'Clientes', Icons.people, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientesScreen()));
          }),

          const SizedBox(height: 25),
          const Text('Operaciones de Cierre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _itemAdmin(context, 'Cierre del Día', Icons.checklist_rounded, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CierreDiaScreen()));
          }),

          // --- 2. NUEVA SECCIÓN: UTILIDADES ---
          const SizedBox(height: 25),
          const Text('Utilidades', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _itemAdmin(context, 'Calculadora de Efectivo', Icons.calculate_outlined, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CalculadoraEfectivoScreen()));
          }),

          const SizedBox(height: 25),
          const Text('Seguridad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _itemAdmin(
              context,
              'Enviar Backup (DB)',
              Icons.backup,
                  () async => await DBHelper.exportarBaseDeDatos(),
              color: Colors.teal.shade700
          ),
        ],
      ),
    );
  }

  Widget _itemAdmin(BuildContext context, String titulo, IconData icono, VoidCallback tap, {Color? color}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icono, color: color ?? Colors.blueGrey[700]),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: tap,
      ),
    );
  }
}