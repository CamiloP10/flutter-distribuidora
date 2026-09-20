import 'package:flutter/material.dart';
import 'factura_screen.dart';
import 'ventas_screen.dart';
import 'cargue_screen.dart';
import 'cargue_historial_screen.dart';
import 'liquidacion_cargue_screen.dart';
import 'historial_liquidaciones_screen.dart';
import 'administracion_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DISTRIBUIDORA LA BELLEZA',
          style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          const SizedBox(height: 10),
          // LOGO
          Image.asset('assets/icon.png', height: 180),
          const SizedBox(height: 25),

          // SECCIÓN FACTURACIÓN
          _buildSeccionAgrupada(
            context,
            titulo: 'FACTURACIÓN',
            botones: [
              _botonGrid(context, 'Nueva', Icons.receipt_long_outlined, const FacturaScreen(), color: Colors.blue.shade700),
              _botonGrid(context, 'Historial', Icons.shopify, VentasScreen(), color: Colors.blue.shade700),
            ],
          ),

          // SECCIÓN CARGUES
          _buildSeccionAgrupada(
            context,
            titulo: 'CARGUES',
            botones: [
              _botonGrid(context, 'Asignar', Icons.local_shipping, const CargueScreen(), color: Colors.indigo.shade600),
              _botonGrid(context, 'Historial', Icons.delivery_dining, const CargueHistorialScreen(), color: Colors.indigo.shade600),
            ],
          ),

          // SECCIÓN LIQUIDACIÓN
          _buildSeccionAgrupada(
            context,
            titulo: 'LIQUIDACIÓN',
            botones: [
              _botonGrid(context, 'Liquidar', Icons.calculate, const LiquidacionCargueScreen(), color: Colors.teal.shade700),
              _botonGrid(context, 'Historial', Icons.history_edu, const HistorialLiquidacionesScreen(), color: Colors.teal.shade700),
            ],
          ),

          const SizedBox(height: 20),

          // BOTÓN ADMINISTRAR
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdministracionScreen()),
              );
            },
            icon: const Icon(Icons.settings_suggest),
            label: const Text('ADMINISTRAR', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- WIDGET QUE CREA EL RECUADRO CON TÍTULO EN LA LÍNEA ---
  Widget _buildSeccionAgrupada(BuildContext context, {required String titulo, required List<Widget> botones}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: titulo,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          // Borde que encierra los botones
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8), // Espacio entre el título y los botones
          child: Row(
            children: [
              Expanded(child: botones[0]),
              const SizedBox(width: 12),
              Expanded(child: botones[1]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonGrid(BuildContext context, String texto, IconData icono, Widget pantalla, {Color? color}) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => pantalla)),
      icon: Icon(icono, size: 18),
      label: Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 50),
        backgroundColor: color ?? Colors.blue.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 1,
      ),
    );
  }
}