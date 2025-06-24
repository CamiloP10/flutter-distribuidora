//Modelo temporal en la UI para manejar productos, cantidades y descuentos antes de guardar, no se guarda en db
import 'producto.dart';

class ProductoSeleccionado {
  final Producto producto;
  int cantidad;
  double precioModificado;

  ProductoSeleccionado({
    required this.producto,
    this.cantidad = 1,
    double? precioModificado,
  }) : this.precioModificado = precioModificado ?? producto.precio;

  double get precioOriginal => producto.precio;

  double get subtotal => cantidad * precioModificado;

  int get productoId => producto.id!;
}
