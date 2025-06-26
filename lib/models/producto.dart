class Producto {
  final int? id; // ID interno de SQLite
  final String codigo;
  final String nombre;
  final String presentacion;
  final double cantidad;
  final double precio;

  Producto({
    this.id,
    required this.codigo,
    required this.nombre,
    required this.presentacion,
    required this.cantidad,
    required this.precio,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id':id,
      'codigo': codigo,
      'nombre': nombre,
      'presentacion': presentacion,
      'cantidad': cantidad,
      'precio': precio,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      codigo: map['codigo'],
      nombre: map['nombre'],
      presentacion: map['presentacion'],
      cantidad: map['cantidad']?.toDouble() ?? 0.0, //conversión segura para decimal
      precio: map['precio'],
    );
  }
}