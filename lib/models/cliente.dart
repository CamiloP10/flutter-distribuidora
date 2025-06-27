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

  //Metodo para copiar el objeto con valores modificados (como el id)
  Cliente copyWith({
    int? id,
    String? nombre,
    String? telefono,
    String? informacion,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      informacion: informacion ?? this.informacion,
    );
  }
}


