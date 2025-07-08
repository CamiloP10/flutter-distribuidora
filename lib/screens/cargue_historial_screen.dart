import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/cargue.dart';
import 'detalle_cargue_screen.dart';

class CargueHistorialScreen extends StatefulWidget {
  const CargueHistorialScreen({super.key});

  @override
  State<CargueHistorialScreen> createState() => _CargueHistorialScreenState();
}

class _CargueHistorialScreenState extends State<CargueHistorialScreen> {
  List<Cargue> _todosLosCargues = [];
  List<Cargue> _carguesFiltrados = [];

  int _limite = 30;

  String _filtroTexto = '';
  String _vehiculoSeleccionado = 'Todos';

  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  final TextEditingController _busquedaController = TextEditingController();

  final List<String> _vehiculos = [
    'Todos',
    'JAC Roja',
    'JAC Blanca',
    'MotoCrg. Gris',
    'MotoCrg. Blanco',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    cargarCargues();
  }

  Future<void> cargarCargues() async {
    final lista = await DBHelper.obtenerCargues();
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    setState(() {
      _todosLosCargues = lista;
      _aplicarFiltro();
    });
  }

  void _aplicarFiltro() {
    List<Cargue> resultado = [..._todosLosCargues];

    if (_filtroTexto.isNotEmpty) {
      final texto = _filtroTexto.toLowerCase();
      resultado = resultado.where((c) {
        return c.id.toString().contains(texto) ||
            c.conductor.toLowerCase().contains(texto);
      }).toList();
    }

    if (_vehiculoSeleccionado != 'Todos') {
      resultado = resultado.where((c) => c.vehiculoAsignado == _vehiculoSeleccionado).toList();
    }

    if (_fechaInicio != null) {
      resultado = resultado.where((c) => c.fecha.isAfter(_fechaInicio!.subtract(const Duration(days: 1)))).toList();
    }

    if (_fechaFin != null) {
      resultado = resultado.where((c) => c.fecha.isBefore(_fechaFin!.add(const Duration(days: 1)))).toList();
    }

    setState(() {
      _carguesFiltrados = resultado.take(_limite).toList();
    });
  }

  void _seleccionarFecha(BuildContext context, bool esInicio) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: esInicio ? (_fechaInicio ?? DateTime.now()) : (_fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
        _limite = 30;
        _aplicarFiltro();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayMas = _carguesFiltrados.length <
        _todosLosCargues.where((c) {
          final texto = _filtroTexto.toLowerCase();
          final coincideTexto = c.id.toString().contains(texto) || c.conductor.toLowerCase().contains(texto);
          final coincideVehiculo = _vehiculoSeleccionado == 'Todos' || c.vehiculoAsignado == _vehiculoSeleccionado;
          final coincideFechaInicio = _fechaInicio == null || c.fecha.isAfter(_fechaInicio!.subtract(const Duration(days: 1)));
          final coincideFechaFin = _fechaFin == null || c.fecha.isBefore(_fechaFin!.add(const Duration(days: 1)));

          return coincideTexto && coincideVehiculo && coincideFechaInicio && coincideFechaFin;
        }).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Cargues')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(
                  controller: _busquedaController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por #Cargue o Conductor',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _filtroTexto = value.trim();
                    _limite = 30;
                    _aplicarFiltro();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _vehiculoSeleccionado,
                        items: _vehiculos.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _vehiculoSeleccionado = val!;
                            _limite = 30;
                            _aplicarFiltro();
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por Vehículo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _seleccionarFecha(context, true),
                            icon: const Icon(Icons.date_range),
                            label: Text(_fechaInicio == null
                                ? 'Desde'
                                : DateFormat('dd/MM/yy').format(_fechaInicio!)),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _seleccionarFecha(context, false),
                            icon: const Icon(Icons.date_range),
                            label: Text(_fechaFin == null
                                ? 'Hasta'
                                : DateFormat('dd/MM/yy').format(_fechaFin!)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _carguesFiltrados.isEmpty
                ? const Center(child: Text("No hay cargues registrados"))
                : ListView.builder(
              itemCount: _carguesFiltrados.length + (hayMas ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _carguesFiltrados.length) {
                  final cargue = _carguesFiltrados[index];
                  return ListTile(
                    title: Text("Cargue #${cargue.id} - ${cargue.vehiculoAsignado}"),
                    subtitle: Text(
                      "${DateFormat('dd/MM/yyyy HH:mm').format(cargue.fecha)} - ${cargue.conductor}",
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalleCargueScreen(cargue: cargue),
                        ),
                      );
                    },
                  );
                } else {
                  return Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _limite += 30;
                          _aplicarFiltro();
                        });
                      },
                      child: const Text('Ver más'),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}