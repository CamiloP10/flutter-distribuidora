import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/cierre_dia_provider.dart';
import '../providers/producto_provider.dart';
import '../utils/pdf_generator.dart';
import 'package:intl/date_symbol_data_local.dart';

class CierreDiaScreen extends StatefulWidget {
  const CierreDiaScreen({super.key});

  @override
  State<CierreDiaScreen> createState() => _CierreDiaScreenState();
}

class _CierreDiaScreenState extends State<CierreDiaScreen> {
  @override
  void initState() {
    super.initState();

    // 1. Inicializamos los datos de idioma para español Colombia
    initializeDateFormatting('es_CO', null).then((_) {
      // 2. Una vez que el idioma está listo, cargamos los datos del provider
      if (mounted) {
        Provider.of<CierreDiaProvider>(context, listen: false).cargarResumenDelDia();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CierreDiaProvider>(context);
    final productProv = Provider.of<ProductoProvider>(context);
    final f = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final fechaTexto = DateFormat('dd / MMMM / yyyy', 'es_CO').format(provider.fechaSeleccionada);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre del Día'),
        backgroundColor: Colors.black,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ENCABEZADO Y SELECTOR
            _buildHeader(context, provider, fechaTexto),
            const SizedBox(height: 20),

            // 2. BOTÓN PDF
            _buildBotonPdf(provider),
            const SizedBox(height: 25),

            // 3. RESUMEN VENTAS
            _buildCardSeccion('Ventas del Período', [
              _fila('Venta Total (Bruta)', provider.totalVentas, f, bold: true),
              _fila('Total Pagado (Recibido)', provider.totalPagado, f, color: Colors.teal),
              _fila('Total a Crédito', provider.totalCredito, f, color: Colors.redAccent),
              const Divider(),
              _fila('Facturas Generadas', provider.totalFacturas.toDouble(), f, isMoney: false),
            ]),

            const SizedBox(height: 15),

            // 4. RECAUDOS
            _buildCardSeccion('Recaudos y Cartera', [
              _fila('Abonos a Créditos Ant.', provider.totalAbonosDelDia, f, color: Colors.green, bold: true),
              if (provider.abonosDetallados.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Listado de abonos:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ...provider.abonosDetallados.map((ab) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _fila('Fact #${ab['facturaId']} - ${ab['cliente']}', (ab['monto'] as num).toDouble(), f, small: true),
                )),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No hay abonos registrados', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ),
            ]),

            const SizedBox(height: 15),

            // 5. RESUMEN MERCANCÍA
            _buildResumenMercancia(provider, productProv, f),

            const SizedBox(height: 15),

            // 6. DETALLE FACTURAS
            _buildExpansionFacturas(provider, f),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- MÉTODOS DE APOYO (Widgets) ---

  Widget _buildHeader(BuildContext context, CierreDiaProvider provider, String fecha) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reporte de Operaciones', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text(fecha, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        IconButton.filled(
          onPressed: () async {
            final nuevaFecha = await showDatePicker(
              context: context,
              initialDate: provider.fechaSeleccionada,
              firstDate: DateTime(2023),
              lastDate: DateTime.now(),
            );
            if (nuevaFecha != null) provider.cambiarFecha(nuevaFecha);
          },
          icon: const Icon(Icons.calendar_month),
          style: IconButton.styleFrom(backgroundColor: Colors.blueGrey),
        ),
      ],
    );
  }

  Widget _buildBotonPdf(CierreDiaProvider provider) {
    return ElevatedButton.icon(
      onPressed: () => _compartirPdf(provider),
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text('GENERAR REPORTE PDF'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCardSeccion(String titulo, List<Widget> hijos) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const Divider(),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, double valor, NumberFormat f, {bool bold = false, Color? color, bool isMoney = true, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: small ? 12 : 14))),
          Text(
            isMoney ? f.format(valor) : valor.toInt().toString(),
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: small ? 12 : 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenMercancia(CierreDiaProvider provider, ProductoProvider productProv, NumberFormat f) {
    // Usamos el método procesarAgrupacion del provider
    final resumen = provider.procesarAgrupacion(provider.facturasDelDia, [], productProv.productos);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: const Icon(Icons.inventory_2, color: Colors.blueGrey),
        title: const Text('Resumen de Mercancía', style: TextStyle(fontWeight: FontWeight.bold)),
        children: resumen.isEmpty
            ? [const ListTile(title: Text('Sin ventas en esta fecha'))]
            : resumen.entries.map((cat) => _buildCategoriaItem(cat, f)).toList(),
      ),
    );
  }

  Widget _buildCategoriaItem(MapEntry<String, Map<String, dynamic>> cat, NumberFormat f) {
    return Column(
      children: [
        Container(
          color: Colors.grey.withOpacity(0.1),
          child: ListTile(
            dense: true,
            title: Text(cat.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text(f.format(cat.value['totalCat'])),
          ),
        ),
        ...(cat.value['productos'] as Map<String, Map<String, double>>).entries.map((p) =>
            ListTile(
              dense: true,
              title: Text(p.key),
              trailing: Text('${p.value['cantidad']?.toInt()} und  |  ${f.format(p.value['subtotal'])}'),
            )
        ),
      ],
    );
  }

  Widget _buildExpansionFacturas(CierreDiaProvider provider, NumberFormat f) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long, color: Colors.teal),
        title: const Text('Facturas del Día', style: TextStyle(fontWeight: FontWeight.bold)),
        children: provider.facturasDelDia.map((fct) {
          final cliente = provider.nombresClientes[fct.clienteId] ?? 'Desconocido';
          // CORRECCIÓN: Usamos la resta de total y pagado para determinar si es crédito
          final bool esCredito = (fct.total - (fct.pagado ?? 0)) > 0;
          return ListTile(
            title: Text('Fact #${fct.id} - $cliente'),
            subtitle: Text(esCredito ? "A CRÉDITO" : "PAGADA",
                style: TextStyle(color: esCredito ? Colors.red : Colors.green, fontSize: 11)),
            trailing: Text(f.format(fct.total)),
          );
        }).toList(),
      ),
    );
  }

  // --- LÓGICA DE PDF ---
  Future<void> _compartirPdf(CierreDiaProvider provider) async {
    try {
      final detalleFacturas = provider.facturasDelDia.map((f) => {
        'id': f.id,
        'cliente': provider.nombresClientes[f.clienteId] ?? 'No registrado',
        'total': f.total,
      }).toList();

      final pdf = await PdfGenerator.generarCierreDiaPDF(
        fecha: provider.fechaSeleccionada,
        totalFacturas: provider.totalFacturas,
        totalPagado: provider.totalPagado,
        totalCredito: provider.totalCredito,
        totalVentas: provider.totalVentas,
        totalAbonos: provider.totalAbonosDelDia,
        detalleFacturas: detalleFacturas,
        abonosDetallados: provider.abonosDetallados,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cierre_${DateFormat('yyyyMMdd').format(provider.fechaSeleccionada)}.pdf');
      await file.writeAsBytes(pdf);

      await Share.shareXFiles([XFile(file.path)], text: 'Cierre del día ${DateFormat('dd/MM/yyyy').format(provider.fechaSeleccionada)}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
    }
  }
}