import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import 'detalle_liquidacion_screen.dart';

class HistorialLiquidacionesScreen extends StatefulWidget {
  const HistorialLiquidacionesScreen({super.key});

  @override
  State<HistorialLiquidacionesScreen> createState() => _HistorialLiquidacionesScreenState();
}

class _HistorialLiquidacionesScreenState extends State<HistorialLiquidacionesScreen> {
  List<Map<String, dynamic>> _todasLasLiquidaciones = [];
  List<Map<String, dynamic>> _liquidacionesFiltradas = [];

  int _cantidadAMostrar = 15;
  final int _pasoPaginacion = 15;
  bool _cargando = true;

  DateTimeRange? _rangoSeleccionado; // Para guardar el filtro de fechas
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _formatMiles = NumberFormat('#,###', 'es_CO');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final datos = await DBHelper.obtenerHistorialLiquidaciones();
    setState(() {
      _todasLasLiquidaciones = datos;
      _liquidacionesFiltradas = datos;
      _cargando = false;
    });
  }

  // Función combinada para filtrar por ID y/o Rango de Fechas
  void _aplicarFiltros() {
    String query = _searchController.text;

    setState(() {
      _liquidacionesFiltradas = _todasLasLiquidaciones.where((liq) {
        final DateTime fechaLiq = DateTime.parse(liq['fecha']);
        final String id = liq['id'].toString();

        // 1. Filtro por ID (si hay texto)
        bool cumpleId = query.isEmpty || id.contains(query);

        // 2. Filtro por Fecha (si hay rango seleccionado)
        bool cumpleFecha = true;
        if (_rangoSeleccionado != null) {
          // Ajustamos el final del rango al último segundo del día para que sea inclusivo
          final inicio = DateTime(_rangoSeleccionado!.start.year, _rangoSeleccionado!.start.month, _rangoSeleccionado!.start.day);
          final fin = DateTime(_rangoSeleccionado!.end.year, _rangoSeleccionado!.end.month, _rangoSeleccionado!.end.day, 23, 59, 59);
          cumpleFecha = fechaLiq.isAfter(inicio) && fechaLiq.isBefore(fin);
        }

        return cumpleId && cumpleFecha;
      }).toList();
      _cantidadAMostrar = _pasoPaginacion;
    });
  }

  // Selector de fechas
  Future<void> _seleccionarRangoFechas() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _rangoSeleccionado,
      saveText: 'Filtrar',
    );

    if (picked != null) {
      _rangoSeleccionado = picked;
      _aplicarFiltros();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsParaMostrar = _liquidacionesFiltradas.take(_cantidadAMostrar).toList();
    final tieneMasResultados = _cantidadAMostrar < _liquidacionesFiltradas.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Liquidaciones'),
        actions: [
          // Botón para limpiar filtros
          if (_rangoSeleccionado != null || _searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () {
                _searchController.clear();
                _rangoSeleccionado = null;
                _aplicarFiltros();
              },
            ),
          // Botón de calendario
          IconButton(
            icon: Icon(Icons.date_range, color: _rangoSeleccionado != null ? Colors.orange : null),
            onPressed: _seleccionarRangoFechas,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Muestra el rango actual si existe
          if (_rangoSeleccionado != null)
            Container(
              color: Colors.orange[50],
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: Text(
                'Filtrando: ${DateFormat('dd/MM/yy').format(_rangoSeleccionado!.start)} al ${DateFormat('dd/MM/yy').format(_rangoSeleccionado!.end)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _aplicarFiltros(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Buscar por ID',
                prefixIcon: const Icon(Icons.tag),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),

          Expanded(
            child: itemsParaMostrar.isEmpty
                ? const Center(child: Text('Sin resultados para los filtros aplicados'))
                : ListView.builder(
              itemCount: itemsParaMostrar.length + (tieneMasResultados ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == itemsParaMostrar.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _cantidadAMostrar += _pasoPaginacion),
                      icon: const Icon(Icons.add),
                      label: const Text('Ver más liquidaciones'),
                    ),
                  );
                }

                final liq = itemsParaMostrar[index];
                final fecha = DateTime.parse(liq['fecha']);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey[100],
                      child: Text('#${liq['id']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                    title: Text('Total: \$${_formatMiles.format(liq['totalFinal'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DetalleLiquidacionScreen(liquidacion: liq)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}