/// Objeto JSON con claves de texto. Las claves del contrato se leen tal cual.
Map<String, dynamic> comoMapa(Object? valor) {
  if (valor is Map<String, dynamic>) return valor;
  if (valor is Map) {
    return valor.map((clave, item) => MapEntry(clave.toString(), item));
  }
  throw const FormatException('Se esperaba un objeto JSON.');
}

class ProblemaApi implements Exception {
  const ProblemaApi({
    required this.estado,
    required this.titulo,
    this.detalle,
    this.errores = const {},
  });

  final int estado;
  final String titulo;
  final String? detalle;
  final Map<String, List<String>> errores;

  String get mensaje {
    if (errores.isNotEmpty) {
      return errores.values.expand((mensajes) => mensajes).join('\n');
    }
    if (detalle != null && detalle!.isNotEmpty) return '$titulo $detalle';
    return titulo;
  }

  factory ProblemaApi.desdeCuerpo(int estado, Object? cuerpo) {
    var titulo = 'La biblioteca respondió $estado.';
    String? detalle;
    final errores = <String, List<String>>{};
    if (cuerpo is Map) {
      final mapa = comoMapa(cuerpo);
      final crudoTitulo = mapa['title'];
      if (crudoTitulo is String && crudoTitulo.isNotEmpty) titulo = crudoTitulo;
      final crudoDetalle = mapa['detail'];
      if (crudoDetalle is String && crudoDetalle.isNotEmpty) detalle = crudoDetalle;
      final crudos = mapa['errors'];
      if (crudos is Map) {
        crudos.forEach((clave, valor) {
          if (valor is List) {
            errores[clave.toString()] = valor.map((item) => item.toString()).toList();
          }
        });
      }
    }
    return ProblemaApi(estado: estado, titulo: titulo, detalle: detalle, errores: errores);
  }
}

/// El refresco no pudo renovar el JWT. Hay que volver a entrar.
class SesionTerminada extends ProblemaApi {
  const SesionTerminada()
    : super(estado: 401, titulo: 'La sesión expiró. Inicia sesión de nuevo.');
}

class DatosUsuario {
  const DatosUsuario({
    required this.id,
    required this.correo,
    required this.nombre,
    required this.rol,
  });

  final String id;
  final String correo;
  final String nombre;
  final String rol;

  bool get esAdmin => rol == 'admin';

  factory DatosUsuario.fromJson(Map<String, dynamic> json) => DatosUsuario(
    id: json['id'] as String? ?? '',
    correo: json['correo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    rol: json['rol'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'correo': correo,
    'nombre': nombre,
    'rol': rol,
  };
}

class RespuestaSesion {
  const RespuestaSesion({
    required this.tokenAcceso,
    required this.expiraEn,
    required this.usuario,
  });

  final String tokenAcceso;
  final DateTime expiraEn;
  final DatosUsuario usuario;

  factory RespuestaSesion.fromJson(Map<String, dynamic> json) => RespuestaSesion(
    tokenAcceso: json['token_acceso'] as String? ?? '',
    expiraEn: DateTime.parse(json['expira_en'] as String),
    usuario: DatosUsuario.fromJson(comoMapa(json['usuario'])),
  );

  Map<String, dynamic> toJson() => {
    'token_acceso': tokenAcceso,
    'expira_en': expiraEn.toUtc().toIso8601String(),
    'usuario': usuario.toJson(),
  };
}

class ResumenLibro {
  const ResumenLibro({
    required this.id,
    required this.titulo,
    required this.autor,
    required this.idioma,
    required this.temas,
    required this.portada,
    required this.totalPaginas,
    required this.caracteresTotales,
  });

  final String id;
  final String titulo;
  final String autor;
  final String idioma;
  final List<String> temas;
  final String? portada;
  final int totalPaginas;
  final int caracteresTotales;

  factory ResumenLibro.fromJson(Map<String, dynamic> json) => ResumenLibro(
    id: json['_id'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    autor: json['autor'] as String? ?? '',
    idioma: json['idioma'] as String? ?? '',
    temas: _textos(json['temas']),
    portada: json['portada'] as String?,
    totalPaginas: _entero(json['total_paginas']),
    caracteresTotales: _entero(json['caracteres_totales']),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'titulo': titulo,
    'autor': autor,
    'idioma': idioma,
    'temas': temas,
    'portada': portada,
    'total_paginas': totalPaginas,
    'caracteres_totales': caracteresTotales,
  };
}

class ListadoLibros {
  const ListadoLibros({
    required this.libros,
    required this.total,
    required this.siguiente,
  });

  final List<ResumenLibro> libros;
  final int total;
  final int? siguiente;

  factory ListadoLibros.fromJson(Map<String, dynamic> json) => ListadoLibros(
    libros: (json['libros'] as List? ?? const [])
        .map((item) => ResumenLibro.fromJson(comoMapa(item)))
        .toList(),
    total: _entero(json['total']),
    siguiente: json['siguiente'] == null ? null : _entero(json['siguiente']),
  );

  Map<String, dynamic> toJson() => {
    'libros': libros.map((libro) => libro.toJson()).toList(),
    'total': total,
    'siguiente': siguiente,
  };
}

class Capitulo {
  const Capitulo({
    required this.numero,
    required this.titulo,
    required this.paginaInicio,
  });

  final int numero;
  final String titulo;
  final int paginaInicio;

  factory Capitulo.fromJson(Map<String, dynamic> json) => Capitulo(
    numero: _entero(json['numero']),
    titulo: json['titulo'] as String? ?? '',
    paginaInicio: _entero(json['pagina_inicio']),
  );

  Map<String, dynamic> toJson() => {
    'numero': numero,
    'titulo': titulo,
    'pagina_inicio': paginaInicio,
  };
}

class FichaLibro {
  const FichaLibro({
    required this.id,
    required this.titulo,
    required this.autor,
    required this.idioma,
    required this.temas,
    required this.portada,
    required this.totalPaginas,
    required this.caracteresTotales,
    required this.capitulos,
  });

  final String id;
  final String titulo;
  final String autor;
  final String idioma;
  final List<String> temas;
  final String? portada;
  final int totalPaginas;
  final int caracteresTotales;
  final List<Capitulo> capitulos;

  factory FichaLibro.fromJson(Map<String, dynamic> json) {
    final resumen = ResumenLibro.fromJson(json);
    return FichaLibro(
      id: resumen.id,
      titulo: resumen.titulo,
      autor: resumen.autor,
      idioma: resumen.idioma,
      temas: resumen.temas,
      portada: resumen.portada,
      totalPaginas: resumen.totalPaginas,
      caracteresTotales: resumen.caracteresTotales,
      capitulos: (json['capitulos'] as List? ?? const [])
          .map((item) => Capitulo.fromJson(comoMapa(item)))
          .toList(),
    );
  }
}

class PaginaLeida {
  const PaginaLeida({
    required this.numeroPagina,
    required this.textoCompleto,
    required this.conteoPalabras,
    required this.totalPaginas,
  });

  final int numeroPagina;
  final String textoCompleto;
  final int conteoPalabras;
  final int totalPaginas;

  factory PaginaLeida.fromJson(Map<String, dynamic> json) => PaginaLeida(
    numeroPagina: _entero(json['numero_pagina']),
    textoCompleto: json['texto_completo'] as String? ?? '',
    conteoPalabras: _entero(json['conteo_palabras']),
    totalPaginas: _entero(json['total_paginas']),
  );

  Map<String, dynamic> toJson() => {
    'numero_pagina': numeroPagina,
    'texto_completo': textoCompleto,
    'conteo_palabras': conteoPalabras,
    'total_paginas': totalPaginas,
  };
}

class SolicitudLogin {
  const SolicitudLogin({required this.correo, required this.contrasena});

  final String correo;
  final String contrasena;

  Map<String, dynamic> toJson() => {
    'correo': correo,
    'contrasena': contrasena,
  };
}

class SolicitudRegistro {
  const SolicitudRegistro({
    required this.correo,
    required this.nombre,
    required this.contrasena,
  });

  final String correo;
  final String nombre;
  final String contrasena;

  Map<String, dynamic> toJson() => {
    'correo': correo,
    'nombre': nombre,
    'contrasena': contrasena,
  };
}

class SolicitudLibro {
  const SolicitudLibro({
    required this.id,
    required this.titulo,
    required this.autor,
    required this.idioma,
    required this.temas,
    required this.portada,
    required this.capitulos,
    required this.paginas,
  });

  final String id;
  final String titulo;
  final String autor;
  final String idioma;
  final List<String> temas;
  final String? portada;
  final List<Capitulo> capitulos;
  final List<String> paginas;

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'autor': autor,
    'idioma': idioma,
    'temas': temas,
    if (portada != null) 'portada': portada,
    'capitulos': capitulos.map((capitulo) => capitulo.toJson()).toList(),
    'paginas': paginas,
  };
}

List<String> _textos(Object? valor) {
  if (valor is! List) return const [];
  return valor.map((item) => item.toString()).toList();
}

int _entero(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return 0;
}
