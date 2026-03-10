import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalculadoraEfectivoScreen extends StatefulWidget {
  const CalculadoraEfectivoScreen({super.key});

  @override
  State<CalculadoraEfectivoScreen> createState() => _CalculadoraEfectivoScreenState();
}

class _CalculadoraEfectivoScreenState extends State<CalculadoraEfectivoScreen> {
  // Mapa para las cantidades de billetes
  final Map<String, int> _cantidades = {
    '100k': 0, '50k': 0, '20k': 0, '10k': 0, '5k': 0, '2k': 0,
  };

  // Valores numéricos para el cálculo
  final Map<String, double> _valores = {
    '100k': 100000, '50k': 50000, '20k': 20000, '10k': 10000, '5k': 5000, '2k': 2000,
  };

  final TextEditingController _monedasController = TextEditingController();
  final f = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  double get _totalBilletes {
    double total = 0;
    _cantidades.forEach((key, cant) {
      total += cant * (_valores[key] ?? 0);
    });
    return total;
  }

  double get _totalFinal {
    double monedas = double.tryParse(_monedasController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return _totalBilletes + monedas;
  }

  void _limpiarTodo() {
    setState(() {
      _cantidades.updateAll((key, value) => 0);
      _monedasController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calculadora reiniciada'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Efectivo'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _limpiarTodo,
            icon: const Icon(Icons.refresh),
            tooltip: 'Limpiar todo',
          )
        ],
      ),
      body: Column(
        children: [
          // TOTAL FLOTANTE (Encabezado)
          Container(
            width: double.infinity,
            color: Colors.blueGrey.shade900,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const Text('TOTAL EN CAJA', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(f.format(_totalFinal),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Billetes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Divider(),
                ..._valores.keys.map((denominacion) => _buildFilaBillete(denominacion)),

                const SizedBox(height: 20),
                const Text('Otros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Divider(),

                // Campo de Monedas
                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.amber),
                  title: const Text('Total en Monedas'),
                  subtitle: TextField(
                    controller: _monedasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '0', prefixText: '\$ '),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 100), // Espacio para no chocar con el teclado
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaBillete(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ),
          // Botón menos
          IconButton(
            onPressed: () {
              if (_cantidades[label]! > 0) {
                setState(() => _cantidades[label] = _cantidades[label]! - 1);
              }
            },
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          ),
          // Cantidad
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)),
            child: Text('${_cantidades[label]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          // Botón más
          IconButton(
            onPressed: () => setState(() => _cantidades[label] = _cantidades[label]! + 1),
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
          ),
          // Subtotal por denominación
          Expanded(
            flex: 3,
            child: Text(f.format(_cantidades[label]! * _valores[label]!),
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}