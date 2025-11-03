import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cargue.dart';
import '../models/factura.dart';
import '../providers/ventas_provider.dart';

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

  Map<String, double> _calcularTotalesVenta(
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
    return {'total': totalVendido};
  }

  // --- 1. FUNCIÓN PARA MOSTRAR EL DIÁLOGO FLOTANTE ---
  void _mostrarDialogoLiquidacion(BuildContext context, double totalVendido) {
    // Controladores para cada campo de texto
    final c100k = TextEditingController();
    final c50k = TextEditingController();
    final c20k = TextEditingController();
    final c10k = TextEditingController();
    final c5k = TextEditingController();
    final c2k = TextEditingController();
    final cMonedas = TextEditingController();

    double t100k = 0, t50k = 0, t20k = 0, t10k = 0, t5k = 0, t2k = 0, tMonedas = 0;
    double totalRecibido = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el modal sea de pantalla completa si es necesario
      builder: (ctx) {
        // StatefulBuilder para que el modal tenga su PROPIO estado y se pueda actualizar en tiempo real
        return StatefulBuilder(
          builder: (modalContext, setModalState) {

            // Función para recalcula
            void recalcular() {
              t100k = (int.tryParse(c100k.text) ?? 0) * 100000;
              t50k = (int.tryParse(c50k.text) ?? 0) * 50000;
              t20k = (int.tryParse(c20k.text) ?? 0) * 20000;
              t10k = (int.tryParse(c10k.text) ?? 0) * 10000;
              t5k = (int.tryParse(c5k.text) ?? 0) * 5000;
              t2k = (int.tryParse(c2k.text) ?? 0) * 2000;
              tMonedas = (double.tryParse(cMonedas.text) ?? 0);

              totalRecibido = t100k + t50k + t20k + t10k + t5k + t2k + tMonedas;

              // Actualiza solo el estado del modal
              setModalState(() {});
            }

            // El padding que se ajusta al teclado
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom),
              child: SingleChildScrollView( // Para poder deslizar si el teclado es grande
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
                    // --- Total Vendido ---
                    Text(
                      'Total Vendido (Facturas):',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      currencyFormat.format(totalVendido),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 24),

                    // --- Dinero Recibido ---
                    Text(
                      'Dinero Recibido:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildDenominacionRow(
                        '\$100.000', c100k, t100k, recalcular),
                    _buildDenominacionRow(
                        '\$50.000', c50k, t50k, recalcular),
                    _buildDenominacionRow(
                        '\$20.000', c20k, t20k, recalcular),
                    _buildDenominacionRow(
                        '\$10.000', c10k, t10k, recalcular),
                    _buildDenominacionRow(
                        '\$5.000', c5k, t5k, recalcular),
                    _buildDenominacionRow(
                        '\$2.000', c2k, t2k, recalcular),

                    // --- Campo de Monedas ---
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Text('Monedas:',
                              style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: cMonedas,
                              onChanged: (_) => recalcular(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Valor total',
                                prefixText: '\$ ',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),

                    // --- Total Recibido (Calculado) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Recibido:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          currencyFormat.format(totalRecibido),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Aquí iría la lógica para guardar la liquidación
                        Navigator.pop(context); // Cierra el modal
                      },
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Confirmar Liquidación'),
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

  // --- 2. WIDGET HELPER PARA LAS FILAS DE DENOMINACIONES ---
  Widget _buildDenominacionRow(String label, TextEditingController controller,
      double subtotal, VoidCallback onRecalcular) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Etiqueta (ej. "$100.000")
          SizedBox(
              width: 70, child: Text(label, style: const TextStyle(fontSize: 16))),
          const Text('x', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),

          // Campo de cantidad
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              onChanged: (_) => onRecalcular(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Cant.'),
            ),
          ),
          const SizedBox(width: 8),
          const Text('=', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),

          // Subtotal calculado
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

    // Calcula el total de la venta (no el recibido)
    final totalesVenta = _calcularTotalesVenta(carguesEnLista, todasLasFacturas);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liquidación de Cargues'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // --- SELECCIÓN DE CARGUE (Dropdown) ---
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

          // --- LISTA DE CARGUES SELECCIONADOS ---
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
      // --- 3. BOTÓN INFERIOR PARA LIQUIDAR (NUEVO) ---

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('Liquidar Cargues Seleccionados'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          // El botón se deshabilita si no hay cargues seleccionados
          onPressed: _carguesSeleccionados.isEmpty
              ? null
              : () {
            // Pasa el total de la VENTA (no del efectivo) al modal
            _mostrarDialogoLiquidacion(context, totalesVenta['total']!);
          },
        ),
      ),
    );
  }
}