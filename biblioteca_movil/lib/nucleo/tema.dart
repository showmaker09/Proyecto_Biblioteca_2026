import 'package:flutter/material.dart';

/// Paleta oficial del frontend web (`frontend/src/app/estilos.css` y
/// `frontend/src/features/auth/Auth.module.css`), organizada en tokens de
/// referencia y roles semánticos para toda la app móvil.
abstract final class ColoresBiblioteca {
  // ─── Superficies y texto base (--fondo, --superficie, --texto, --acento) ───
  static const fondo = Color(0xFFFFFFFF);
  static const superficie = Color(0xFFFFFFFF);
  // Lienzo gris azulado muy claro bajo las tarjetas blancas: la diferencia de
  // tono más la sombra crea la jerarquía sin recurrir a bordes en todo.
  static const lienzo = Color(0xFFF3F5F9);
  static const superficieAlt = Color(0xFFF4F4F4);
  static const borde = Color(0xFFD9D9D9);
  static const texto = Color(0xFF111111);
  static const textoSuave = Color(0xFF6B6B6B);
  static const acento = Color(0xFF111111);
  static const acentoTexto = Color(0xFFFFFFFF);
  static const tinta = Color(0xFF141414);

  // ─── Escala Pizarra (--pizarra-*) ───
  static const pizarra50 = Color(0xFFF8FAFC);
  static const pizarra100 = Color(0xFFF1F5F9);
  static const pizarra200 = Color(0xFFE2E8F0);
  static const pizarra300 = Color(0xFFCBD5E1);
  static const pizarra400 = Color(0xFF94A3B8);
  static const pizarra500 = Color(0xFF64748B);
  static const pizarra600 = Color(0xFF475569);
  static const pizarra900 = Color(0xFF0F172A);

  // ─── Azul claro de lectura (--azul-rgb, --azul-50, --azul-200) ───
  static const azul = Color(0xFF2563EB);
  static const azul50 = Color(0xFFF5F8FF);
  static const azul100 = Color(0xFFE8F0FE);
  static const azul200 = Color(0xFFDDE6FB);
  static const azul300 = Color(0xFFBFDBFE);
  static const azulClaro = Color(0xFF60A5FA);

  // ─── Foco de campos: aro azul claro en lugar de filete negro ───
  static const focoBorde = Color(0xFF93C5FD);

  // ─── Panel Hero Auth (linear-gradient 155deg #182234 -> #0b1120) ───
  static const heroInicio = Color(0xFF182234);
  static const heroFin = Color(0xFF0B1120);

  // ─── Estados semánticos ───
  static const errorFondo = Color(0xFFFEF2F2);
  static const errorBorde = Color(0xFFFECACA);
  static const errorTexto = Color(0xFF991B1B);
  static const exito = Color(0xFF059669);
  static const aviso = Color(0xFFB7791F);

  // ─── Lector modo oscuro (LectorPage.module.css .oscuro) ───
  static const lectorOscuroFondo = Color(0xFF000000);
  static const lectorOscuroTexto = Color(0xFFFFFFFF);
  static const lectorOscuroBorde = Color(0xFF3A3A3A);

  // ─── Elevación con tinte pizarra: sombra de contacto + sombra ambiental ───
  // Nivel 1: tarjetas en reposo sobre el lienzo.
  static const sombraTarjeta = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 18,
      spreadRadius: -6,
      offset: Offset(0, 8),
    ),
  ];

  // Nivel 2: tarjetas presionadas o bajo el dedo.
  static const sombraAlzada = <BoxShadow>[
    BoxShadow(
      color: Color(0x120F172A),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x240F172A),
      blurRadius: 30,
      spreadRadius: -8,
      offset: Offset(0, 16),
    ),
  ];

  // Nivel 3: superficies flotantes (hojas inferiores, navegación, diálogos).
  static const sombraFlotante = <BoxShadow>[
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x330F172A),
      blurRadius: 48,
      spreadRadius: -12,
      offset: Offset(0, 24),
    ),
  ];

  // Velo para modales: pizarra translúcida en lugar de negro plano.
  static const veloModal = Color(0x660F172A);
}

/// Estilos de texto compartidos que no encajan en un rol de `TextTheme`.
abstract final class TextosBiblioteca {
  /// Rótulo de sección en versalitas pequeñas (por encima de grupos de opciones).
  static const etiquetaSeccion = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    height: 1.2,
    color: ColoresBiblioteca.pizarra500,
  );
}

ThemeData temaBiblioteca() {
  const esquema = ColorScheme(
    brightness: Brightness.light,
    primary: ColoresBiblioteca.acento,
    onPrimary: ColoresBiblioteca.acentoTexto,
    primaryContainer: ColoresBiblioteca.pizarra100,
    onPrimaryContainer: ColoresBiblioteca.texto,
    secondary: ColoresBiblioteca.azul,
    onSecondary: ColoresBiblioteca.fondo,
    secondaryContainer: ColoresBiblioteca.pizarra100,
    onSecondaryContainer: ColoresBiblioteca.texto,
    tertiary: ColoresBiblioteca.azul,
    onTertiary: ColoresBiblioteca.fondo,
    tertiaryContainer: ColoresBiblioteca.azul50,
    onTertiaryContainer: ColoresBiblioteca.texto,
    error: ColoresBiblioteca.errorTexto,
    onError: ColoresBiblioteca.fondo,
    errorContainer: ColoresBiblioteca.errorFondo,
    onErrorContainer: ColoresBiblioteca.errorTexto,
    surface: ColoresBiblioteca.fondo,
    onSurface: ColoresBiblioteca.texto,
    onSurfaceVariant: ColoresBiblioteca.textoSuave,
    surfaceContainerLowest: ColoresBiblioteca.superficie,
    surfaceContainerLow: ColoresBiblioteca.pizarra50,
    surfaceContainer: ColoresBiblioteca.pizarra100,
    surfaceContainerHigh: ColoresBiblioteca.superficieAlt,
    surfaceContainerHighest: ColoresBiblioteca.pizarra200,
    outline: ColoresBiblioteca.borde,
    outlineVariant: ColoresBiblioteca.pizarra200,
    shadow: ColoresBiblioteca.pizarra900,
    scrim: ColoresBiblioteca.pizarra900,
    inverseSurface: ColoresBiblioteca.heroFin,
    onInverseSurface: ColoresBiblioteca.pizarra50,
    inversePrimary: ColoresBiblioteca.azulClaro,
  );

  final base = ThemeData(colorScheme: esquema, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: ColoresBiblioteca.lienzo,
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresBiblioteca.lienzo,
      foregroundColor: ColoresBiblioteca.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'serif',
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: ColoresBiblioteca.texto,
      ),
      shape: Border(
        bottom: BorderSide(color: ColoresBiblioteca.pizarra200),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ColoresBiblioteca.superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: ColoresBiblioteca.azul50,
      iconTheme: WidgetStateProperty.resolveWith((estados) {
        final activo = estados.contains(WidgetState.selected);
        return IconThemeData(
          color: activo
              ? ColoresBiblioteca.texto
              : ColoresBiblioteca.pizarra500,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((estados) {
        final activo = estados.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
          color: activo
              ? ColoresBiblioteca.texto
              : ColoresBiblioteca.pizarra500,
        );
      }),
    ),
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.w600,
        color: ColoresBiblioteca.texto,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.w600,
        color: ColoresBiblioteca.texto,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.w600,
        color: ColoresBiblioteca.texto,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.w600,
        color: ColoresBiblioteca.texto,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: ColoresBiblioteca.texto,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: ColoresBiblioteca.textoSuave,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoresBiblioteca.acento,
        foregroundColor: ColoresBiblioteca.acentoTexto,
        disabledBackgroundColor: ColoresBiblioteca.pizarra200,
        disabledForegroundColor: ColoresBiblioteca.pizarra500,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: ColoresBiblioteca.superficie,
        foregroundColor: ColoresBiblioteca.texto,
        side: const BorderSide(color: ColoresBiblioteca.borde),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ColoresBiblioteca.texto,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresBiblioteca.superficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: const TextStyle(color: ColoresBiblioteca.pizarra500),
      labelStyle: const TextStyle(color: ColoresBiblioteca.pizarra600),
      floatingLabelStyle: const TextStyle(color: ColoresBiblioteca.texto),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: ColoresBiblioteca.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: ColoresBiblioteca.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(
          color: ColoresBiblioteca.focoBorde,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: ColoresBiblioteca.errorTexto),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(
          color: ColoresBiblioteca.errorTexto,
          width: 1.5,
        ),
      ),
    ),
    cardTheme: const CardThemeData(
      color: ColoresBiblioteca.superficie,
      surfaceTintColor: Colors.transparent,
      shadowColor: Color(0x660F172A),
      elevation: 1.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: ColoresBiblioteca.pizarra100,
      selectedColor: ColoresBiblioteca.acento,
      checkmarkColor: ColoresBiblioteca.acentoTexto,
      side: const BorderSide(color: ColoresBiblioteca.pizarra200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(
        color: ColoresBiblioteca.pizarra600,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: const TextStyle(
        color: ColoresBiblioteca.acentoTexto,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: ColoresBiblioteca.pizarra200,
      thickness: 1,
    ),
    // Hojas inferiores ancladas abajo con esquinas superiores redondeadas
    // (`mostrarHojaInferior` dibuja su propia asa y cabecera).
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColoresBiblioteca.superficie,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: ColoresBiblioteca.veloModal,
      showDragHandle: true,
      dragHandleColor: ColoresBiblioteca.pizarra300,
      dragHandleSize: Size(40, 4.5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: ColoresBiblioteca.superficie,
      surfaceTintColor: Colors.transparent,
      barrierColor: ColoresBiblioteca.veloModal,
      elevation: 12,
      shadowColor: Color(0x660F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'serif',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ColoresBiblioteca.texto,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColoresBiblioteca.acento,
      linearTrackColor: ColoresBiblioteca.pizarra100,
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: ColoresBiblioteca.azul,
      textColor: ColoresBiblioteca.fondo,
    ),
  );
}
