import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/cargue.dart';
import '../models/factura.dart';
import '../providers/ventas_provider.dart';
import '../utils/pdf_generator.dart';

// (Clase ThousandsInputFormatter sin cambios)
class ThousandsInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,##0', 'es_CO');
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final unformatted = newValue.text.replaceAll('.', '');
    final number = int.tryParse(unformatted) ?? 0;
    final formatted = _formatter.format(number);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// --- PANTALLA PRINCIPAL ---
class LiquidacionCargueScreen extends StatefulWidget {
  const LiquidacionCargueScreen({super.key});

  @override
  State<LiquidacionCargueScreen> createState() =>
      _LiquidacionCargueScreenState();
}

class _LiquidacionCargueScreenState extends State<LiquidacionCargueScreen> {
  final Set<int> _carguesSeleccionados = {};
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'es_CO');
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatosIniciales();
    });
  }

  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final provider = Provider.of<VentasProvider>(context, listen: false);
    await provider.cargarFacturas();
    await provider.cargarCargues();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  double _calcularTotalVendido(
      List<Cargue> todosLosCargues, List<Factura> todasLasFacturas) {
    double totalVendido = 0;

    final carguesFiltrados = todosLosCargues
        .where((c) => _carguesSeleccionados.contains(c.id))
        .toList();

    final Set<int> facturasIds = {};
    for (final cargue in carguesFiltrados) {
      facturasIds.addAll(cargue.facturaIds); // Corregido
    }

    for (final factura in todasLasFacturas) {
      if (facturasIds.contains(factura.id)) {
        totalVendido += factura.total;
      }
    }
    return totalVendido;
  }

  // --- FUNCIÓN DE MODAL (ACTUALIZADA) ---
  void _mostrarDialogoLiquidacion(
      BuildContext context,
      double totalVendido,
      List<Cargue> carguesLiquidados,
      List<Factura> todasLasFacturas,
      ) {

    // Controladores
    final c100k = TextEditingController();
    final c50k = TextEditingController();
    final c20k = TextEditingController();
    final c10k = TextEditingController();
    final c5k = TextEditingController();
    final c2k = TextEditingController();
    final cMonedas = TextEditingController();
    final cNequi = TextEditingController();
    final cDevoluciones = TextEditingController();
    final cCreditos = TextEditingController();

    // Mapas de datos
    final Map<String, int> cantidades = {};
    final Map<String, double> subtotales = {};
    double tMonedas = 0;
    double tNequi = 0;
    double tDevoluciones = 0;
    double tCreditos = 0;
    double totalRecibido = 0; // Total de EFECTIVO (Billetes + Monedas)
    double efectivoEsperado = 0;
    double diferencia = 0;

    bool _isConfirming = false;

    // Función para quitar formato antes de parsear
    double _parseFormatted(String text) {
      final unformatted = text.replaceAll('.', '');
      return double.tryParse(unformatted) ?? 0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {

            // --- LÓGICA DE 'RECALCULAR' ACTUALIZADA ---
            void recalcular() {
              cantidades['100k'] = int.tryParse(c100k.text.replaceAll('.', '')) ?? 0;
              cantidades['50k'] = int.tryParse(c50k.text.replaceAll('.', '')) ?? 0;
              cantidades['20k'] = int.tryParse(c20k.text.replaceAll('.', '')) ?? 0;
              cantidades['10k'] = int.tryParse(c10k.text.replaceAll('.', '')) ?? 0;
              cantidades['5k'] = int.tryParse(c5k.text.replaceAll('.', '')) ?? 0;
              cantidades['2k'] = int.tryParse(c2k.text.replaceAll('.', '')) ?? 0;

              subtotales['100k'] = cantidades['100k']! * 100000.0;
              subtotales['50k'] = cantidades['50k']! * 50000.0;
              subtotales['20k'] = cantidades['20k']! * 20000.0;
              subtotales['10k'] = cantidades['10k']! * 10000.0;
              subtotales['5k'] = cantidades['5k']! * 5000.0;
              subtotales['2k'] = cantidades['2k']! * 2000.0;

              tMonedas = _parseFormatted(cMonedas.text);
              tNequi = _parseFormatted(cNequi.text);
              tDevoluciones = _parseFormatted(cDevoluciones.text);
              tCreditos = _parseFormatted(cCreditos.text);

              // 1. El efectivo esperado es la venta MENOS todo lo que no es efectivo físico
              efectivoEsperado = totalVendido - tDevoluciones - tCreditos - tNequi;

              // 2. El total recibido es SOLO el efectivo físico (Billetes + Monedas)
              totalRecibido = subtotales.values.fold(0.0, (a, b) => a + b) + tMonedas;

              // 3. La diferencia es el efectivo físico recibido vs el esperado
              diferencia = totalRecibido - efectivoEsperado;

              setModalState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arqueo de Caja',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),

                    // --- SECCIÓN DE TOTALES (ACTUALIZADA) ---
                    _buildTotalRow(
                        'Total Vendido (Facturas):',
                        currencyFormat.format(totalVendido),
                        Colors.black),

                    _buildInputRow('Devoluciones:', cDevoluciones, recalcular,
                        prefix: '- \$ ', color: Colors.red),

                    _buildInputRow('Créditos:', cCreditos, recalcular,
                        prefix: '- \$ ', color: Colors.orange),

                    // --- CAMBIO: NEQUI AHORA ES UN DESCUENTO ---
                    _buildInputRow('Nequi:', cNequi, recalcular,
                        prefix: '- \$ ', color: Colors.purple, icon: Icons.phone_android),

                    const Divider(),
                    _buildTotalRow(
                        'Efectivo Esperado:',
                        currencyFormat.format(efectivoEsperado),
                        Colors.blue,
                        isLarge: true),
                    const Divider(height: 24),

                    // --- SECCIÓN DINERO RECIBIDO (EFECTIVO) ---
                    Text(
                      'Dinero Recibido (Efectivo Físico):',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildDenominacionRow('\$100.000', c100k,
                        subtotales['100k'] ?? 0, recalcular),
                    _buildDenominacionRow('\$50.000', c50k,
                        subtotales['50k'] ?? 0, recalcular),
                    _buildDenominacionRow('\$20.000', c20k,
                        subtotales['20k'] ?? 0, recalcular),
                    _buildDenominacionRow('\$10.000', c10k,
                        subtotales['10k'] ?? 0, recalcular),
                    _buildDenominacionRow(
                        '\$5.000', c5k, subtotales['5k'] ?? 0, recalcular),
                    _buildDenominacionRow(
                        '\$2.000', c2k, subtotales['2k'] ?? 0, recalcular),

                    _buildInputRow('Monedas:', cMonedas, recalcular,
                        prefix: '\$ '),

                    // (El campo Nequi se movió arriba)

                    const Divider(height: 24),

                    // --- Totales Recibidos ---
                    _buildTotalRow(
                        'Efectivo Recibido:',
                        currencyFormat.format(totalRecibido),
                        Colors.green,
                        isLarge: true),

                    _buildTotalRow(
                        'Diferencia:',
                        currencyFormat.format(diferencia),
                        diferencia == 0 ? Colors.black : Colors.orange,
                        isLarge: true),

                    const SizedBox(height: 20),

                    // --- BOTÓN DE CONFIRMAR (Sin cambios en la lógica, solo pasa los datos) ---
                    ElevatedButton(
                      onPressed: _isConfirming ? null : () async {
                        setModalState(() => _isConfirming = true);

                        try {
                          // Generar PDF
                          final pdfBytes = await PdfGenerator.generarLiquidacionPDF(
                            totalVendido: totalVendido,
                            totalDevoluciones: tDevoluciones,
                            totalCreditos: tCreditos,
                            totalNequi: tNequi,
                            totalRecibido: totalRecibido, // Este es solo el efectivo
                            cantidades: cantidades,
                            subtotales: subtotales,
                            monedas: tMonedas,
                            carguesLiquidados: carguesLiquidados,
                            todasLasFacturas: todasLasFacturas,
                          );

                          // Guardar y Compartir PDF
                          final dir = await getTemporaryDirectory();
                          final file = File('${dir.path}/liquidacion_${DateTime.now().millisecondsSinceEpoch}.pdf');
                          await file.writeAsBytes(pdfBytes);

                          await Share.shareXFiles(
                            [XFile(file.path)],
                            text: 'Liquidación de Caja - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                          );

                          if (modalContext.mounted) {
                            Navigator.pop(modalContext);
                          }

                        } catch (e) {
                          if (modalContext.mounted) {
                            ScaffoldMessenger.of(modalContext).showSnackBar(
                              SnackBar(content: Text('Error al generar PDF: $e')),
                            );
                          }
                        } finally {
                          if(mounted) {
                            setModalState(() => _isConfirming = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50)),
                      child: _isConfirming
                          ? const CircularProgressIndicator()
                          : const Text('Confirmar Liquidación y Generar PDF'),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // (Widget helper denominación - sin cambios)
  Widget _buildDenominacionRow(String label, TextEditingController controller,
      double subtotal, VoidCallback onRecalcular) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 70, child: Text(label, style: const TextStyle(fontSize: 16))),
          const Text('x', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              onChanged: (_) => onRecalcular(),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsInputFormatter(),
              ],
              decoration: const InputDecoration(hintText: 'Cant.'),
            ),
          ),
          const SizedBox(width: 8),
          const Text('=', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              currencyFormat.format(subtotal),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // (Widget helper input - sin cambios)
  Widget _buildInputRow(String label, TextEditingController controller,
      VoidCallback onRecalcular, {IconData? icon, String prefix = '', Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: color ?? Colors.grey), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 16, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onRecalcular(),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsInputFormatter(),
              ],
              textAlign: TextAlign.right,
              style: TextStyle(color: color),
              decoration: InputDecoration(
                  hintText: 'Valor total',
                  prefixText: prefix,
                  prefixStyle: TextStyle(color: color)
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    // (build... sin cambios)
    final ventasProvider = context.watch<VentasProvider>();
    final List<Cargue> todosLosCargues = [...ventasProvider.cargues];
    todosLosCargues.sort((a, b) => b.fecha.compareTo(a.fecha));
    final List<Factura> todasLasFacturas = ventasProvider.facturas;

    final List<Cargue> carguesEnLista = todosLosCargues
        .where((c) => _carguesSeleccionados.contains(c.id))
        .toList();
    final List<Cargue> carguesDisponibles = todosLosCargues
        .where((c) => !_carguesSeleccionados.contains(c.id))
        .toList();

    final totalVendido = _calcularTotalVendido(carguesEnLista, todasLasFacturas);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liquidación de Cargues'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // (Dropdown... sin cambios)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: DropdownButtonFormField<int>(
              hint: const Text('Seleccione un cargue para añadir...'),
              value: null,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add),
              ),
              items: carguesDisponibles.map((cargue) {
                return DropdownMenuItem<int>(
                  value: cargue.id,
                  child: Text(
                    '#${cargue.id} - ${cargue.conductor} (${cargue.vehiculoAsignado})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (int? selectedId) {
                if (selectedId != null) {
                  setState(() {
                    _carguesSeleccionados.add(selectedId);
                  });
                }
              },
            ),
          ),

          // (Lista de cargues... sin cambios)
          const Divider(),
          const Text(
            'Cargues a liquidar:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: carguesEnLista.isEmpty
                ? const Center(
                child: Text(
                  'Añada cargues desde el menú superior.',
                  style: TextStyle(color: Colors.grey),
                ))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: carguesEnLista.length,
              itemBuilder: (context, index) {
                final cargue = carguesEnLista[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                        'Cargue #${cargue.id} - ${cargue.vehiculoAsignado}'),
                    subtitle: Text(
                        '${cargue.conductor}\n${DateFormat('dd/MM/yyyy HH:mm').format(cargue.fecha)}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle,
                          color: Colors.red),
                      tooltip: 'Quitar de la lista',
                      onPressed: () {
                        setState(() {
                          _carguesSeleccionados.remove(cargue.id);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // (Botón inferior... sin cambios)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('Liquidar Cargues Seleccionados'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _carguesSeleccionados.isEmpty
              ? null
              : () {
            _mostrarDialogoLiquidacion(
              context,
              totalVendido,
              carguesEnLista,
              todasLasFacturas,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, Color color, {bool isLarge = false}) {
    final textStyle = isLarge
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.titleMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textStyle),
          Text(
            value,
            style: textStyle?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}