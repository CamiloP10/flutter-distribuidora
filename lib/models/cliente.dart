class Cliente {
  int? id;
  String nombre;
  String telefono;
  String informacion;

  Cliente({
    this.id,
    required this.nombre,
    required this.telefono,
    required this.informacion,
  });

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      nombre: map['nombre'],
      telefono: map['telefono'],
      informacion: map['informacion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'informacion': informacion,
    };
  }
}


