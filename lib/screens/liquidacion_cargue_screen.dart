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
import 'dart:convert';
import 'package:inv/db/db_helper.dart';
import '../providers/cliente_provider.dart';

import '../providers/cierre_dia_provider.dart';
import '../providers/producto_provider.dart';

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
      facturasIds.addAll(cargue.facturaIds);
    }

    for (final factura in todasLasFacturas) {
      if (facturasIds.contains(factura.id)) {
        totalVendido += factura.total;
      }
    }
    return totalVendido;
  }

  void _abrirDialogoDetalle( //Diálogo de Captura (Función de Apoyo para los JSON)
      BuildContext context,
      String titulo,
      List<Map<String, dynamic>> lista,
      VoidCallback onActualizar) {

    final nameCtrl = TextEditingController();
    final montoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Añadir a $titulo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre / Concepto'),
              textCapitalization: TextCapitalization.words,
            ),
            TextField(
              controller: montoCtrl,
              decoration: const InputDecoration(labelText: 'Monto (\$)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsInputFormatter()],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && montoCtrl.text.isNotEmpty) {
                final monto = double.tryParse(montoCtrl.text.replaceAll('.', '')) ?? 0;
                lista.add({'nombre': nameCtrl.text, 'monto': monto});
                onActualizar();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  // Esta función crea el diseño de la lista que ves en pantalla
  // Añadimos 'VoidCallback onRemove' al final de los parámetros
  Widget _buildFilaDinamica(String label, List<Map<String, dynamic>> lista, Color color, VoidCallback onAdd, VoidCallback onRemove) {
    double totalLista = lista.fold(0.0, (sum, item) => sum + item['monto']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(width: 8),
                Text(currencyFormat.format(totalLista), style: TextStyle(color: color, fontSize: 13)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
              onPressed: onAdd,
            ),
          ],
        ),
        if (lista.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Column(
              children: lista.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text('• ${entry.value['nombre']}', style: const TextStyle(fontSize: 12))),
                      Text(currencyFormat.format(entry.value['monto']), style: const TextStyle(fontSize: 12)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () {
                          lista.removeAt(entry.key);
                          onRemove(); // <--- Ahora usamos la función que pasamos por parámetro
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

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

    // Mapas de datos
    final Map<String, int> cantidades = {};
    final Map<String, double> subtotales = {};
    double tMonedas = 0;
    double tNequi = 0;
    double tDevoluciones = 0;
    double tCreditos = 0;
    double tRecaudoCreditos = 0;
    double totalRecibido = 0;
    double efectivoEsperado = 0;
    double diferencia = 0;

    bool _isConfirming = false;

    double _parseFormatted(String text) {
      final unformatted = text.replaceAll('.', '');
      return double.tryParse(unformatted) ?? 0;
    }

    // Listas para almacenar los desgloses dinámicos
    List<Map<String, dynamic>> listaCreditosNuevos = [];
    List<Map<String, dynamic>> listaCreditosAntiguos = [];
    List<Map<String, dynamic>> listaNequi = [];
    List<Map<String, dynamic>> listaDevoluciones = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {

            void recalcular() {
              // 1. Cálculos de billetes (Efectivo Físico)
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

              // 2. Sumar montos de las listas dinámicas (JSON)
              tNequi = listaNequi.fold(0.0, (sum, item) => sum + item['monto']);
              tDevoluciones = listaDevoluciones.fold(0.0, (sum, item) => sum + item['monto']);
              tCreditos = listaCreditosNuevos.fold(0.0, (sum, item) => sum + item['monto']);
              tRecaudoCreditos = listaCreditosAntiguos.fold(0.0, (sum, item) => sum + item['monto']);

              // 3. Totales Finales
              // El esperado es lo vendido - lo que no es efectivo + lo recaudado de antes
              efectivoEsperado = (totalVendido - tDevoluciones - tCreditos - tNequi) + tRecaudoCreditos;

              // El recibido es la suma de billetes + monedas
              totalRecibido = subtotales.values.fold(0.0, (a, b) => a + b) + tMonedas;

              diferencia = totalRecibido - efectivoEsperado;

              setModalState(() {});
            }

            // --- LÓGICA DE ETIQUETA Y COLOR ---
            String labelDiferencia = 'Diferencia:';
            Color colorDiferencia = Colors.black;

            if (diferencia < 0) {
              labelDiferencia = 'Faltante:';
              colorDiferencia = Colors.red;
            } else if (diferencia > 0) {
              labelDiferencia = 'A favor:';
              colorDiferencia = Colors.green;
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

                    _buildTotalRow(
                        'Total Vendido (Facturas):',
                        currencyFormat.format(totalVendido),
                        Colors.black),


                    const SizedBox(height: 10),

// --- NUEVAS FILAS DINÁMICAS ---
                    _buildFilaDinamica('Devoluciones: -', listaDevoluciones, Colors.red, () {
                      _abrirDialogoDetalle(context, 'Devoluciones', listaDevoluciones, recalcular);
                    }, recalcular),

                    _buildFilaDinamica('Créditos (Nuevos): -', listaCreditosNuevos, Colors.orange, () {
                      _abrirDialogoDetalle(context, 'Créditos Nuevos generados', listaCreditosNuevos, recalcular);
                    }, recalcular),

                    _buildFilaDinamica('Nequi (Virtual): -', listaNequi, Colors.purple, () {
                      _abrirDialogoDetalle(context, 'Pagos recibidos por Nequi o virtual', listaNequi, recalcular);
                    }, recalcular),

                    _buildFilaDinamica('Créditos (Antiguos): +', listaCreditosAntiguos, Colors.teal, () {
                      _abrirDialogoDetalle(context, 'Recaudo de Créditos Antiguos', listaCreditosAntiguos, recalcular);
                    }, recalcular),
// ------------------------------

                    const Divider(),
                    _buildTotalRow(
                        'Efectivo Esperado:',
                        currencyFormat.format(efectivoEsperado),
                        Colors.blue,
                        isLarge: true),
                    const Divider(height: 24),

                    Text(
                      'Dinero Recibido (Efectivo Físico):',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildDenominacionRow('\$100.000', c100k, subtotales['100k'] ?? 0, recalcular),
                    _buildDenominacionRow('\$50.000', c50k, subtotales['50k'] ?? 0, recalcular),
                    _buildDenominacionRow('\$20.000', c20k, subtotales['20k'] ?? 0, recalcular),
                    _buildDenominacionRow('\$10.000', c10k, subtotales['10k'] ?? 0, recalcular),
                    _buildDenominacionRow('\$5.000', c5k, subtotales['5k'] ?? 0, recalcular),
                    _buildDenominacionRow('\$2.000', c2k, subtotales['2k'] ?? 0, recalcular),

                    _buildInputRow('Monedas:', cMonedas, recalcular, prefix: '\$ '),

                    const Divider(height: 24),

                    _buildTotalRow(
                        'Total Efectivo:',
                        currencyFormat.format(totalRecibido),
                        Colors.green,
                        isLarge: true),

                    // LÓGICA DINÁMICA
                    _buildTotalRow(
                        labelDiferencia,
                        currencyFormat.format(diferencia),
                        colorDiferencia,
                        isLarge: true),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _isConfirming ? null : () async {
                        setModalState(() => _isConfirming = true);

                        try {
                          final cierreProv = Provider.of<CierreDiaProvider>(context, listen: false);
                          final productoProv = Provider.of<ProductoProvider>(context, listen: false);
                          final clienteProv = Provider.of<ClienteProvider>(context, listen: false);

                          // 1. Obtener datos maestros (Detalles de DB y Productos de Provider)
                          final todosLosDetalles = await DBHelper.obtenerTodosLosDetalles();
                          final todosLosProductos = productoProv.productos;

                          // 2. Filtrar y Agrupar (Usando la lógica centralizada del Provider)
                          final facturasIdsEnCargues = carguesLiquidados.expand((c) => c.facturaIds).toSet();
                          final facturasDelCargue = todasLasFacturas.where((f) => facturasIdsEnCargues.contains(f.id)).toList();

                          final resumenVentasFinal = cierreProv.procesarAgrupacion(
                              facturasDelCargue,
                              todosLosDetalles,
                              todosLosProductos
                          );

                          // 3. Preparar datos para persistencia en SQLite
                          final datosLiquidacion = {
                            'fecha': DateTime.now().toIso8601String(),
                            'totalEfectivo': totalRecibido,
                            'totalNequi': tNequi,
                            'totalCreditosNuevos': tCreditos,
                            'totalCreditosAntiguos': tRecaudoCreditos,
                            'totalDevoluciones': tDevoluciones,
                            'desgloseBilletes': jsonEncode({
                              'billetes': cantidades,
                              'total_monedas': tMonedas,
                            }),
                            'totalFinal': totalVendido,
                            'observaciones': 'Liquidación de ${carguesLiquidados.length} cargues',
                            // NUEVOS CAMPOS V4
                            'detallesCreditosNuevos': jsonEncode(listaCreditosNuevos),
                            'detallesCreditosAntiguos': jsonEncode(listaCreditosAntiguos),
                            'detallesNequi': jsonEncode(listaNequi),
                            'detallesDevoluciones': jsonEncode(listaDevoluciones),
                          };

                          final idsCargues = carguesLiquidados.map((c) => c.id).toList();

                          // 4. Guardar liquidación y obtener el ID generado
                          final int nuevoIdLiquidacion = await DBHelper.insertarLiquidacionCompleta(datosLiquidacion, idsCargues);

                          // 5. Asegurar que los clientes estén cargados para el PDF
                          if (clienteProv.clientes.isEmpty) {
                            await clienteProv.cargarClientes();
                          }

                          // 6. Generar el PDF con el resumen ya procesado
                          final pdfBytes = await PdfGenerator.generarLiquidacionPDF(
                            liquidacionId: nuevoIdLiquidacion,
                            totalVendido: totalVendido,
                            totalDevoluciones: tDevoluciones,
                            totalCreditos: tCreditos,
                            totalNequi: tNequi,
                            totalRecaudoCreditos: tRecaudoCreditos,
                            totalRecibido: totalRecibido,
                            cantidades: cantidades,
                            subtotales: subtotales,
                            monedas: tMonedas,
                            carguesLiquidados: carguesLiquidados,
                            todosLosClientes: clienteProv.clientes,
                            resumenVentas: resumenVentasFinal,    // Mapa procesado por el Provider
                            facturasDelCargue: facturasDelCargue, // Lista filtrada para el detalle final

                            listaNequi: listaNequi,
                            listaDevoluciones: listaDevoluciones,
                            listaCreditosNuevos: listaCreditosNuevos,
                            listaCreditosAntiguos: listaCreditosAntiguos,
                          );

                          // 7. Guardar temporalmente y compartir
                          final dir = await getTemporaryDirectory();
                          final String nombreArchivo = "Liquidacion_Caja_$nuevoIdLiquidacion.pdf";
                          final file = File('${dir.path}/$nombreArchivo');
                          await file.writeAsBytes(pdfBytes);

                          await Share.shareXFiles(
                            [XFile(file.path)],
                            text: 'Liquidación de Caja - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                          );

                          if (modalContext.mounted) {
                            Navigator.pop(modalContext);
                            if (mounted) {
                              setState(() {
                                _carguesSeleccionados.clear();
                              });
                            }
                          }

                        } catch (e) {
                          debugPrint("Error en liquidación: $e");
                          if (modalContext.mounted) {
                            ScaffoldMessenger.of(modalContext).showSnackBar(
                              SnackBar(content: Text('Error en el proceso: $e')),
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
                          ? const CircularProgressIndicator(color: Colors.white)
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
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: DropdownButtonFormField<int>(
              key: UniqueKey(), // <-- ESTO ES CLAVE: Obliga a Flutter a refrescar el widget limpiamente
              hint: const Text('Seleccione un cargue para añadir...'),
              value: null, // Mantenerlo en null para que siempre muestre el hint
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add),
              ),
              // Filtramos para que no aparezcan los que ya seleccionamos (opcional pero recomendado)
              items: carguesDisponibles
                  .where((c) => !_carguesSeleccionados.contains(c.id))
                  .map((cargue) {
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
                    // Añadimos el ID a la lista de seleccionados
                    _carguesSeleccionados.add(selectedId);
                  });
                }
              },
            ),
          ),

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