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

  // 1. CAMBIO DE LÍMITE A 15
  int _limite = 15;
  int _totalResultadosFiltrados = 0;

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
    // Ordenar por fecha descendente (más recientes primero)
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    setState(() {
      _todosLosCargues = lista;
      _aplicarFiltro();
    });
  }

  void _aplicarFiltro() {
    List<Cargue> resultado = [..._todosLosCargues];

    // Filtro por texto
    if (_filtroTexto.isNotEmpty) {
      final texto = _filtroTexto.toLowerCase();
      resultado = resultado.where((c) {
        return c.id.toString().contains(texto) ||
            c.conductor.toLowerCase().contains(texto);
      }).toList();
    }

    // Filtro por vehículo
    if (_vehiculoSeleccionado != 'Todos') {
      resultado = resultado.where((c) => c.vehiculoAsignado == _vehiculoSeleccionado).toList();
    }

    // Filtro por rango de fechas
    if (_fechaInicio != null) {
      resultado = resultado.where((c) => c.fecha.isAfter(_fechaInicio!.subtract(const Duration(days: 1)))).toList();
    }
    if (_fechaFin != null) {
      resultado = resultado.where((c) => c.fecha.isBefore(_fechaFin!.add(const Duration(days: 1)))).toList();
    }

    setState(() {
      _totalResultadosFiltrados = resultado.length;
      _carguesFiltrados = resultado.take(_limite).toList();
    });
  }

  void _seleccionarFecha(BuildContext context, bool esInicio) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      setState(() {
        if (esInicio) _fechaInicio = picked;
        else _fechaFin = picked;
        _limite = 15; // Reiniciar límite al filtrar
        _aplicarFiltro();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Lógica simplificada para saber si hay más datos por cargar
    final bool hayMas = _carguesFiltrados.length < _totalResultadosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Cargues'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Sección de Filtros
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _busquedaController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por # o Conductor',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _filtroTexto = value.trim();
                    _limite = 15;
                    _aplicarFiltro();
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _vehiculoSeleccionado,
                        items: _vehiculos.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _vehiculoSeleccionado = val!;
                            _limite = 15;
                            _aplicarFiltro();
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Vehículo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botones de Fecha
                    Column(
                      children: [
                        _botonFecha(true),
                        const SizedBox(height: 4),
                        _botonFecha(false),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Listado
          Expanded(
            child: _carguesFiltrados.isEmpty
                ? const Center(child: Text("No hay cargues que coincidan"))
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _carguesFiltrados.length + (hayMas ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _carguesFiltrados.length) {
                  final cargue = _carguesFiltrados[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.local_shipping, color: Colors.white, size: 20),
                      ),
                      title: Text("Cargue #${cargue.id} - ${cargue.conductor}",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        "${DateFormat('dd/MM/yyyy  HH:mm').format(cargue.fecha)}\nVehículo: ${cargue.vehiculoAsignado}",
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetalleCargueScreen(cargue: cargue),
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  // 3. BOTÓN VER MÁS
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _limite += 15; // Cargar otros 15
                            _aplicarFiltro();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Ver más cargues...'),
                      ),
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

  Widget _botonFecha(bool esInicio) {
    final fecha = esInicio ? _fechaInicio : _fechaFin;
    return SizedBox(
      height: 35,
      width: 120,
      child: ElevatedButton(
        onPressed: () => _seleccionarFecha(context, esInicio),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 11),
        ),
        child: Text(fecha == null
            ? (esInicio ? 'Desde' : 'Hasta')
            : DateFormat('dd/MM/yy').format(fecha)),
      ),
    );
  }
}