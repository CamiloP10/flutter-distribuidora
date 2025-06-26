//Representa cada línea de la factura: un producto, su cantidad, precio y subtotal.
class DetalleFactura {
  int? id;
  int facturaId;
  int productoId;
  double cantidad;
  double precioOriginal;
  double precioModificado;

  DetalleFactura({
    this.id,
    required this.facturaId,
    required this.productoId,
    required this.cantidad,
    required this.precioOriginal,
    required this.precioModificado,
  });

  double get subtotal => cantidad * precioModificado;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'facturaId': facturaId,
      'productoId': productoId,
      'cantidad': cantidad,
      'precioOriginal': precioOriginal,
      'precioModificado': precioModificado,
    };
  }

  factory DetalleFactura.fromMap(Map<String, dynamic> map) {
    return DetalleFactura(
      id: map['id'],
      facturaId: map['facturaId'],
      productoId: map['productoId'],
      cantidad: map['cantidad'],
      precioOriginal: map['precioOriginal'],
      precioModificado: map['precioModificado'],
    );
  }
}