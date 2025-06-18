class DetalleFactura {
  final int? id;
   int facturaId;
  final int productoId;
  final int cantidad;
  final double precioUnitario;

  DetalleFactura({
    this.id,
    required this.facturaId,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get total => cantidad * precioUnitario;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'facturaId': facturaId,
      'productoId': productoId,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory DetalleFactura.fromMap(Map<String, dynamic> map) {
    return DetalleFactura(
      id: map['id'],
      facturaId: map['facturaId'],
      productoId: map['productoId'],
      cantidad: map['cantidad'],
      precioUnitario: map['precioUnitario'],
    );
  }
}

