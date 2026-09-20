import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CalculadoraEfectivoScreen extends StatefulWidget {
  const CalculadoraEfectivoScreen({super.key});

  @override
  State<CalculadoraEfectivoScreen> createState() => _CalculadoraEfectivoScreenState();
}

class _CalculadoraEfectivoScreenState extends State<CalculadoraEfectivoScreen> {
  final Map<String, double> _valores = {
    '100.000': 100000, '50.000': 50000, '20.000': 20000,
    '10.000': 10000, '5.000': 5000, '2.000': 2000,
  };

  final Map<String, TextEditingController> _controllers = {
    '100.000': TextEditingController(),
    '50.000': TextEditingController(),
    '20.000': TextEditingController(),
    '10.000': TextEditingController(),
    '5.000': TextEditingController(),
    '2.000': TextEditingController(),
  };

  final TextEditingController _monedasController = TextEditingController();
  final f = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  double get _totalBilletes {
    double total = 0;
    _controllers.forEach((key, controller) {
      double cant = double.tryParse(controller.text) ?? 0;
      total += cant * (_valores[key] ?? 0);
    });
    return total;
  }

  double get _totalFinal {
    String textoLimpio = _monedasController.text.replaceAll(RegExp(r'[^0-9]'), '');
    double monedas = double.tryParse(textoLimpio) ?? 0;
    return _totalBilletes + monedas;
  }

  void _limpiarTodo() {
    setState(() {
      for (var controller in _controllers.values) {
        controller.clear();
      }
      _monedasController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calculadora reiniciada'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _controllers.values) { c.dispose(); }
    _monedasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Efectivo'),
        backgroundColor: Colors.black,
      ),
      // --- BOTÓN FLOTANTE AZUL ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _limpiarTodo,
        label: const Text('BORRAR TODO', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.delete_sweep),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.blueGrey.shade900,
            padding: const EdgeInsets.symmetric(vertical: 25),
            child: Column(
              children: [
                const Text('TOTAL', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.2)),
                Text(f.format(_totalFinal),
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Row(
                  children: [
                    Icon(Icons.money, size: 20, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Text('Billetes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const Divider(),
                ..._valores.keys.map((denominacion) => _buildFilaInput(denominacion)),
                const SizedBox(height: 25),
                const Row(
                  children: [
                    Icon(Icons.savings_outlined, size: 20, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Text('Otros / Monedas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(flex: 3, child: Text('Total ingresado', style: TextStyle(fontSize: 16))),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _monedasController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                          decoration: const InputDecoration(
                            hintText: '0',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                // Espacio extra para que el FAB no tape el último campo
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaInput(String label) {
    double subtotal = (double.tryParse(_controllers[label]!.text) ?? 0) * _valores[label]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _controllers[label],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              f.format(subtotal),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: subtotal > 0 ? Colors.blueGrey.shade800 : Colors.grey.shade400,
                fontSize: 15,
                fontWeight: subtotal > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final int value = int.parse(newText);
    final formatter = NumberFormat('#,###', 'es_CO');
    String newString = formatter.format(value).replaceAll(',', '.');
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}