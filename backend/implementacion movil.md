# Implementación móvil

Cliente móvil en Flutter para la biblioteca, con Android como primer destino. La app lee y escribe solo por los verbos HTTP que ya expone `Biblioteca.Api`. La cámara y el OCR viven en el teléfono: se encuadra una página, se extrae el texto y se guarda un `.txt`. La foto no se sube y se borra del caché al terminar el reconocimiento.

Este documento describe el método, la arquitectura, la justificación y los pasos para construirlo. No cambia el backend. Señala tres ajustes de configuración que hacen falta para que un Android hable con la API tal como está hoy.

## Decisión

Usar **Flutter stable** y generar el proyecto solo para Android. El código de la app es Dart. El proyecto se llama `biblioteca_movil` y vive al lado de `backend/` y `frontend/`, fuera de `Biblioteca.slnx`. No referencia `Biblioteca.Api`. Habla con Kestrel por HTTPS (en desarrollo, por HTTP) y guarda el texto reconocido en el almacenamiento privado de la app.

El encuadre usa el paquete `camera`: vista previa de la cámara trasera dentro de la propia pantalla, para que la página llene el marco. El OCR usa `google_mlkit_text_recognition` con el alfabeto latino de ML Kit, en el dispositivo y sin red. Ese modelo cubre el español.

La cámara del sistema (`image_picker`) queda como repuesto si el emulador no expone una cámara usable. El primer corte se prueba en un teléfono Android real, porque el OCR de una página impresa depende de la óptica y de la luz.

## Por qué Flutter encaja con esta API

La API ya es el límite del sistema. `Program.cs` publica JSON en snake_case, autentica con JWT y persiste en MongoDB Atlas (`Biblioteca_Ingenieria`). Un cliente móvil necesita un cliente HTTP, pantallas y acceso a la cámara de Android. Flutter entrega las tres en un solo proyecto Dart, y los plugins de cámara y de ML Kit corren en el embedding de Android del mismo proceso.

| Hecho del backend | Consecuencia para el móvil |
|---|---|
| Contrato HTTP JSON, sin SDK propio | La app habla HTTP. Los modelos Dart se escriben contra ese JSON. |
| Fallback de autorización: toda ruta pide usuario autenticado | La app manda `Authorization: Bearer` en catálogo y lector. |
| Cuatro rutas anónimas: registro, login, refresco, cierre | El arranque de sesión no pide token. |
| JSON `SnakeCaseLower` | Cada campo declara su clave (`token_acceso`, `texto_completo`, `_id`). |
| Las lecturas proyectan resúmenes o una sola página | El teléfono no descarga el libro entero. Una página cabe en memoria. |
| CORS no está configurado | `package:http` no pasa por el navegador. CORS no aplica. |
| Audiencia del JWT: `biblioteca-web` | La pone el servidor al firmar. El móvil usa el token que devuelve el login. |
| Límite de cuerpo: 1 MB, y 15 MB solo en `POST /libros` | Una foto (varios MB) no cabe en las rutas actuales. El OCR ocurre en el teléfono. |
| Android es el dispositivo de la entrega | Un APK usa la cámara trasera, el permiso de cámara y ML Kit dentro del proceso. |

La superficie es pequeña: formularios, un cliente HTTP, la cámara y un archivo de texto. El embedding de Android se queda en lo que ya traen los plugins. La primera versión no añade código Kotlin propio.

El teléfono no abre Mongo, no lleva `JWT_CLAVE` y no ejecuta el pipeline de Python. El proyecto Flutter no entra en la solución de .NET. Si compartiera el ensamblado de la API, arrastraría el driver de Mongo y Kestrel, y además el lenguaje no coincide.

## Contrato que la app consume

Verbos reales a octubre de 2026. No hay `PUT`, `PATCH` ni `DELETE`.

| Uso | Método y ruta | Auth | Límite |
|---|---|---|---|
| Crear cuenta (siempre rol lector) | `POST /auth/registro` | anónimo | 5 / min por IP |
| Entrar | `POST /auth/login` | anónimo | 5 / min por IP |
| Renovar el JWT | `POST /auth/refrescar` | cookie `biblioteca_refresco` | 30 / min por IP |
| Salir | `POST /auth/cerrar-sesion` | cookie | 30 / min por IP |
| Perfil | `GET /auth/yo` | Bearer | 120 / min por usuario |
| Catálogo | `GET /libros` | Bearer | 120 / min por usuario |
| Ficha y capítulos | `GET /libros/{id}` | Bearer | 120 / min |
| Una página | `GET /libros/{id}/paginas/{n}` | Bearer | 120 / min |
| Idiomas del filtro | `GET /idiomas` | Bearer | 120 / min |
| Alta de un libro | `POST /libros` | rol admin | 20 / min por usuario |

Los límites salen de `appsettings.json` (`Limites`). Al pasarse, la API responde `429` con `Retry-After`.

### Sesión

Definida en `GestorSesiones` y `OpcionesSesion`.

- Login y registro responden `token_acceso`, `expira_en` y `usuario` (`id`, `correo`, `nombre`, `rol`).
- El refresco **no** viaja en el JSON. Viaja en la cookie httpOnly `biblioteca_refresco`, 7 días, `SameSite=Strict`, `Secure` en producción.
- `Path` de la cookie: `/auth` en producción (`appsettings.json`) y `/api/auth` en Development (`appsettings.Development.json`, pensado para el proxy de Vite).
- El JWT dura 15 minutos. Algoritmo HS256, emisor `biblioteca-api`, audiencia `biblioteca-web`.
- Cada refresco gasta el token una sola vez y emite otro de la misma familia. Reutilizar uno viejo fuera de una ventana de 30 segundos revoca la familia.
- Dentro de esos 30 segundos, una segunda llamada con la cookie ya gastada responde igual sin sesión: el servidor no entrega otro JWT al duplicado. Solo evita revocar la familia, porque asume que el navegador ya guardó la cookie nueva.
- Cinco contraseñas mal cierran la cuenta 15 minutos. El mensaje de error es el mismo si el correo no existe.
- El rol admin no se pide en el registro. Se asigna por consola (`dotnet run -- asignar-rol`).

`SameSite` y `Path` son reglas para el cliente HTTP que decide si adjunta la cookie. El servidor, al leer `Cookie`, no vuelve a comprobar el `Path`. Una app que guarda el valor y lo pone ella misma en `POST /auth/refrescar` y `POST /auth/cerrar-sesion` funciona con el `RutaCookie` de Development (`/api/auth`) y con el de producción (`/auth`).

### Catálogo y lector

`GET /libros` acepta:

- `desde`: desplazamiento. Cada respuesta trae como mucho 20 libros.
- `orden`: `titulo` (defecto), `autor` o `largos`.
- `q`: busca en título y autor, sin distinguir mayúsculas ni acentos, máximo 100 caracteres.
- `idioma`: código de 2 o 3 letras (`es`).
- `id` repetido (`?id=a&id=b`): pide esos libros, como mucho 20. Sirve para «continuar leyendo».

La respuesta es `{ libros, total, siguiente }`. `siguiente` es el próximo `desde`, o `null` si no hay más.

`GET /libros/{id}` devuelve la ficha más `capitulos: [{ numero, titulo, pagina_inicio }]`, sin el arreglo de páginas.

`GET /libros/{id}/paginas/{numero}` devuelve `{ numero_pagina, texto_completo, conteo_palabras, total_paginas }`. `numero` empieza en 1. Un número menor que 1 o inexistente es `404`.

`GET /idiomas` devuelve la lista de códigos presentes, ordenada.

### Alta (`POST /libros`)

Solo admin. El cuerpo imita una carpeta del pipeline, con las páginas ya como textos:

```json
{
  "id": "004_la_celestina",
  "titulo": "La Celestina",
  "autor": "Rojas, Fernando de",
  "idioma": "es",
  "temas": ["Teatro"],
  "portada": "https://ejemplo.com/portada.jpg",
  "capitulos": [
    { "numero": 1, "titulo": "Acto I", "pagina_inicio": 1 }
  ],
  "paginas": [
    "Texto de la primera página.",
    "Texto de la segunda página."
  ]
}
```

Reglas que el servidor ya valida (`CrearLibro`):

- `id`: 3 a 100 caracteres, minúsculas, números o guion bajo, como `004_la_celestina`.
- `titulo` 1–300, `autor` 1–200, `idioma` de 2 o 3 letras.
- Hasta 50 temas de 1–300 caracteres.
- `portada`, si viene, es un `https` de hasta 500 caracteres.
- Entre 1 y 5000 páginas de texto. Hasta 1000 capítulos. `pagina_inicio` tiene que existir.
- Tope de cuerpo: 15 MB. Un documento de Mongo no puede pasar de 16 MB.
- El servidor calcula `conteo_palabras` y `caracteres_totales`. Un `id` repetido responde `409`.

La app de un lector no llama esta ruta. Un admin puede acumular los `.txt` del escáner y publicarlos con este `POST`. La foto no entra en el cuerpo.

## Arquitectura

```text
┌──────────────────────────────────────────────┐
│  biblioteca_movil  (Flutter, Dart, Android)  │
│                                              │
│  Pantallas (widgets)                         │
│    Login · Registro · Catálogo · Lector      │
│    Escáner (CameraPreview)                   │
│         │                                    │
│         ▼                                    │
│  Casos de uso                                │
│    Sesion · Catalogo · Lectura · Escaner     │
│         │                    │               │
│         ▼                    ▼               │
│  ClienteBiblioteca      MotorOcr             │
│  un http.Client         camera (trasera)     │
│  Bearer en memoria      ML Kit, script latin │
│  refresco en            .txt en documentos   │
│  flutter_secure_storage de la app            │
└──────────────┬───────────────────────────────┘
               │  HTTPS  JSON snake_case
               │  Authorization: Bearer
               │  Cookie: biblioteca_refresco
               │     solo en /auth/refrescar
               │     y /auth/cerrar-sesion
               ▼
┌──────────────────────────────────────────────┐
│  Biblioteca.Api  (Kestrel, net10)            │
│    /auth/*    /libros    /idiomas            │
│    JWT 15 min · cookie de refresco 7 días    │
│    límites por minuto                        │
└──────────────┬───────────────────────────────┘
               │
               ▼
        MongoDB Atlas
        Biblioteca_Ingenieria
        colecciones Libros, Usuarios, sesiones
```

Tres capas dentro de la app:

1. **Pantallas.** Widgets de Flutter. Pintan estado y llaman un caso de uso. No arman JSON ni abren la cámara fuera de la pantalla del escáner.
2. **Casos de uso.** «Iniciar sesión», «listar la página 3», «pasar la foto a texto». Orquestan el cliente y el OCR. Son clases Dart sin widgets.
3. **Infraestructura.** `ClienteBiblioteca` (un solo `http.Client`), `AlmacenSesion` (JWT en un campo de memoria, refresco en `flutter_secure_storage`) y `MotorOcr` (cámara + ML Kit + archivo).

`main.dart` crea el cliente y el almacén una vez y los publica con `provider`. Las pantallas los leen. Nadie construye otro `http.Client`.

El backend no gana un módulo móvil. Sigue siendo la misma API que usa el front de Vite. El embedding de Android (`android/`) solo declara permisos, el nombre del paquete y, en depuración, HTTP claro. La lógica queda en `lib/`.

### Carpetas del proyecto

```text
script_biblioteca/
  backend/                         API existente. El móvil no la referencia.
  frontend/                        Vite. Sigue con su proxy y su cookie.
  biblioteca_movil/
    pubspec.yaml
    lib/
      main.dart                    crea cliente, almacén y Provider
      aplicacion.dart              MaterialApp y rutas
      nucleo/
        modelos.dart               tipos del JSON
        cliente_biblioteca.dart    login, refresco, GET, POST /libros
        almacen_sesion.dart        memoria + flutter_secure_storage
      funciones/
        cuenta/                    login, registro, cierre
        catalogo/                  listado, búsqueda, ficha
        lector/                    una página, anterior, siguiente
        escaner/
          vista_camara.dart        CameraController y vista previa
          motor_ocr.dart           ML Kit, alfabeto latino
          guardar_texto.dart       UTF-8 en el directorio de la app
    android/
      app/src/main/AndroidManifest.xml    INTERNET, CAMERA
      app/src/debug/AndroidManifest.xml   HTTP claro solo en debug
```

Los modelos del móvil son clases propias, copiadas del contrato. `fromJson` y `toJson` se escriben a mano: son pocos tipos y las claves quedan visibles. Duplicar esos tipos es el límite correcto con una API en C#.

### Sesión en el cliente

```text
login o registro
    → POST /auth/login  (o /auth/registro)
    → cuerpo: token_acceso + expira_en + usuario
    → Set-Cookie: biblioteca_refresco=...
    → guardar el JWT en memoria
    → guardar solo el valor de la cookie en flutter_secure_storage

cada GET o POST de catálogo
    → Authorization: Bearer {jwt}
    → sin cabecera Cookie
    → si 401: esperar el refresco único (ver abajo)
              guardar JWT y cookie nuevos
              repetir la petición una sola vez
    → si el refresco responde 401: borrar el almacén y volver a Login

al arrancar la app
    → leer flutter_secure_storage
    → si hay valor: POST /auth/refrescar
         Cookie: biblioteca_refresco={valor}
    → si vale, sustituir JWT y cookie por los nuevos y entrar al catálogo

cerrar sesión
    → POST /auth/cerrar-sesion con esa misma cabecera Cookie
    → borrar JWT y flutter_secure_storage
```

El refresco rota en cada uso. Hay que persistir el valor nuevo que trae `Set-Cookie` antes de dar la sesión por buena. Si el siguiente arranque manda el valor viejo, el servidor lo trata como reutilizado.

Varias pantallas pueden recibir 401 a la vez cuando el JWT de 15 minutos vence (el catálogo y la precarga de la página vecina). Esas llamadas comparten **un solo** `Future` de refresco. La segunda no vuelve a enviar la cookie que la primera ya gastó. Un duplicado no recibe JWT y, pasados 30 segundos, revoca la familia entera.

```dart
Future<bool>? _refrescoEnCurso;

Future<bool> refrescar() {
  final enCurso = _refrescoEnCurso;
  if (enCurso != null) return enCurso;
  final nuevo = _refrescarReal().whenComplete(() => _refrescoEnCurso = null);
  _refrescoEnCurso = nuevo;
  return nuevo;
}
```

`package:http` junta las cabeceras repetidas en `headers` y una fecha `Expires` lleva comas. El valor se lee con `headersSplitValues['set-cookie']`, se toma el elemento que empieza por `biblioteca_refresco=` y se corta en el primer `;`.

```dart
String? valorRefresco(http.Response respuesta) {
  final cookies = respuesta.headersSplitValues['set-cookie'] ?? const [];
  for (final cruda in cookies) {
    final par = cruda.split(';').first.trim();
    const prefijo = 'biblioteca_refresco=';
    if (par.startsWith(prefijo)) return par.substring(prefijo.length);
  }
  return null;
}
```

En un navegador la cookie es httpOnly para que JavaScript no la lea. En la app el proceso es quien la guarda. `flutter_secure_storage` la deja en el Keystore de Android (EncryptedSharedPreferences). El JWT no se persiste: dura 15 minutos y se vuelve a pedir con el refresco. La posición de lectura (id del libro y número de página) va en `shared_preferences`, que no es un almacén secreto.

Un solo `http.Client` para toda la app, creado en `main`:

- La raíz sale de `--dart-define=API_BASE=...`. El valor de desarrollo por defecto es `http://10.0.2.2:8000`.
- `Content-Type` y `Accept` son `application/json`.
- Las claves del JSON se escriben en snake_case en cada `toJson` / `fromJson`. `_id` se mapea a mano.
- Ante un `429`, se espera lo que diga `Retry-After` antes de volver a intentar.
- El cierre y el refresco son las únicas peticiones que llevan `Cookie`.

### Escáner (fuera de la API)

```text
usuario abre el escáner
    → permiso CAMERA en tiempo de ejecución
    → CameraController de la cámara trasera
      ResolutionPreset.high
    → CameraPreview ocupa la pantalla; la página llena el marco
    → takePicture() escribe un JPEG temporal
    → InputImage.fromFilePath (ML Kit lee la rotación EXIF)
    → TextRecognizer(script: TextRecognitionScript.latin)
    → string
    → borrar el JPEG temporal
    → la persona corrige el texto
    → UTF-8 en el directorio de documentos de la app
```

La vista previa es la herramienta de encuadre. `ResolutionPreset.high` alcanza para una página impresa. `veryHigh` o `max` alargan el reconocimiento y ocupan más memoria sin cambiar el contrato.

«Extraer las letras» significa quedarse con el texto impreso y descartar la imagen. El motor ya devuelve palabras y bloques. Un filtro que borre números y puntuación existe como opción, y empeora un libro: se pierden puntos, rayas de diálogo y números de verso. El guardado por defecto conserva el texto tal como lo devolvió el OCR.

El archivo de la foto vive en el caché de la app el tiempo del reconocimiento. Al terminar, se borra. No hace falta permiso de galería ni de almacenamiento público: el `.txt` se escribe en el directorio de documentos de la app, privado de este paquete.

La luz pareja y la página llenando el marco importan más que cambiar de motor. `flutter_tesseract_ocr` con `spa.traineddata` queda como repuesto si una tipografía concreta falla. Pesa más y exige preprocesar la foto.

En Android el ciclo de la cámara es estricto: un solo `CameraController`, `initialize()` antes de `takePicture()`, y `dispose()` al salir de la pantalla. Volver a entrar crea otro controlador. El reconocedor de ML Kit también se cierra (`close()`) al salir.

Publicar el escaneo en el catálogo es un paso aparte y solo para admin: se juntan los `.txt` en el orden de las páginas y se llama `POST /libros`. El lector normal se queda con el archivo local y sigue leyendo el catálogo por `GET`. La acción de publicar solo se muestra si `usuario.rol` es `admin`. El servidor igual responde 403 si un lector la llama.

## Tres ajustes para que el teléfono llegue a esta API

Sin ellos el cliente compila y el refresco, o la red, fallan. Son configuración, no endpoints nuevos.

### 1. Cómo viaja la cookie

`appsettings.Development.json` pone `RutaCookie` en `/api/auth` porque el front entra por el proxy de Vite (`/api` → `127.0.0.1:8000`). Kestrel escucha el refresco en `/auth/refrescar`.

Un jar de cookies que obedece `Path` no reenvía a `/auth/refrescar` una cookie guardada con path `/api/auth`. Por eso esta app **no** usa un jar. Guarda el valor y lo envía en la cabecera `Cookie` solo en las dos rutas de sesión. Así el `Path` de Development y el de producción sirven sin tocar el JSON.

Cambiar `RutaCookie` a `/auth` en Development rompe el refresco del navegador si Vite no reescribe el `Path` de la cookie. El front web se queda como está.

`CookieSegura` es `false` en Development, así el login por HTTP puede devolver la cookie. En producción es `true` y la base de la app tiene que ser `https`.

### 2. Dónde escucha Kestrel

`launchSettings.json` ata el perfil `http` a `http://127.0.0.1:8000`.

- Emulador de Android: `10.0.2.2` es el host visto desde el emulador. `http://10.0.2.2:8000` llega a ese loopback. No hace falta abrir Kestrel en `0.0.0.0`.
- Teléfono por USB: `adb reverse tcp:8000 tcp:8000` hace que `http://127.0.0.1:8000` en el teléfono sea el Kestrel del PC. La API sigue en loopback y la cámara es la del aparato. Es el camino para probar el OCR.
- Teléfono solo por WiFi: no ve el loopback del PC. Hay que escuchar en la LAN (por ejemplo `http://0.0.0.0:8000`), abrir el puerto 8000 en el firewall de Windows para redes privadas, y apuntar la app a `http://192.168.x.x:8000`.

La raíz se inyecta al arrancar:

```powershell
flutter run --dart-define=API_BASE=http://10.0.2.2:8000
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
flutter run --dart-define=API_BASE=http://192.168.1.20:8000
```

En producción la base es el HTTPS público. Un build de release no lleva una IP de desarrollo por defecto.

### 3. HTTP claro solo en depuración

Android, desde el nivel de API 28, bloquea HTTP. El manifiesto de `src/debug` puede permitirlo. El de `src/main`, que es el que entra en el release, no lo permite.

`android/app/src/debug/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:usesCleartextTraffic="true" />
</manifest>
```

En una WiFi compartida (un salón de clase) los login cuentan por IP: 5 por minuto entre todos los teléfonos que salgan con la misma dirección, y 5 fallos bloquean esa cuenta 15 minutos. Para el OCR conviene el cable y `adb reverse`, que no abre la API a esa red.

## Pasos para realizarlo

### 1. SDK y proyecto

Hace falta Flutter stable, el SDK de Android y un aparato o emulador. `flutter doctor` tiene que dejar verde Android antes de seguir.

Desde `script_biblioteca`:

```powershell
flutter create --org com.biblioteca --platforms android biblioteca_movil
```

Eso crea el embedding de Android (actividad Flutter, Gradle, manifiesto) y `lib/main.dart`. No se añade una referencia al proyecto de C#. iOS no entra en este corte. Si más adelante hiciera falta, se agrega la plataforma y en `Info.plist` la clave `NSCameraUsageDescription`. El simulador de iOS, en la misma máquina, sí alcanza `http://127.0.0.1:8000`.

### 2. Paquetes

Desde `biblioteca_movil`, `flutter pub add` escribe en `pubspec.yaml` la versión que resuelva el SDK del día:

```powershell
flutter pub add http provider flutter_secure_storage shared_preferences camera google_mlkit_text_recognition path_provider share_plus
```

- `http`: un cliente para toda la app.
- `provider`: publica ese cliente y el almacén de sesión.
- `flutter_secure_storage`: el valor de `biblioteca_refresco` en el Keystore.
- `shared_preferences`: id del libro y página actual.
- `camera`: vista previa y captura.
- `google_mlkit_text_recognition`: ML Kit en el dispositivo. El modelo latino viaja dentro del APK y reconoce sin red.
- `path_provider`: directorio de documentos y caché.
- `share_plus`: sacar el `.txt` del teléfono.

`image_picker` se añade solo si la vista previa no sirve en el emulador y se quiere la cámara del sistema para una prueba.

### 3. Manifiesto y minSdk

En `android/app/src/main/AndroidManifest.xml`, dentro de `manifest`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

`required="false"` permite instalar la app en un emulador sin cámara. La pantalla del escáner explica que no hay cámara, y el resto (login, catálogo, lector) sigue usable.

El permiso de cámara se pide en tiempo de ejecución antes de `CameraController.initialize()`. El de internet es de instalación.

ML Kit de texto pide `minSdk` 21 o superior. En el módulo `app` (`android/app/build.gradle` o `build.gradle.kts`) el `minSdk` queda en 21 como mínimo, o en el valor que ya traiga Flutter si es mayor. No se pide `READ_MEDIA_IMAGES` ni acceso al almacenamiento público.

El atributo `usesCleartextTraffic` se queda en el manifiesto de debug del apartado anterior. El release no lo lleva.

Flutter deja desactivada la ofuscación de release. Se queda así hasta que el OCR esté probado en un APK release. Si más adelante se enciende `isMinifyEnabled`, hay que conservar las reglas de consumidor que ya trae el plugin de ML Kit.

### 4. Modelos

Clases en `lib/nucleo/modelos.dart`. Los nombres Dart van en camelCase y cada clave JSON se escribe tal cual.

- `RespuestaSesion`: `token_acceso`, `expira_en`, `usuario`.
- `DatosUsuario`: `id`, `correo`, `nombre`, `rol`.
- `ResumenLibro`: `_id`, `titulo`, `autor`, `idioma`, `temas`, `portada`, `total_paginas`, `caracteres_totales`.
- `ListadoLibros`: `libros`, `total`, `siguiente`.
- `FichaLibro`: lo anterior más `capitulos` (`numero`, `titulo`, `pagina_inicio`).
- `PaginaLeida`: `numero_pagina`, `texto_completo`, `conteo_palabras`, `total_paginas`.
- `SolicitudLogin`, `SolicitudRegistro`, `SolicitudLibro` para los POST.

Los errores de validación llegan como Problem Details (`title`, `errors`). Conviene un tipo pequeño para mostrarlos en el formulario. Un test de `flutter test` cubre un JSON de cada tipo, incluido `_id` y `siguiente: null`.

### 5. Cliente HTTP y almacén de sesión

Implementar `ClienteBiblioteca` con los métodos de la tabla de contrato y nada más.

- `iniciarSesion` / `registrar` leen el cuerpo y, de `headersSplitValues`, la cookie `biblioteca_refresco`, y la pasan a `AlmacenSesion`.
- `preparar` al arrancar: si hay refresco guardado, llama a `refrescar` con la cabecera `Cookie`.
- `enviar` añade el Bearer. Ante un 401 de una ruta que no sea de `/auth`, espera el `Future` único de refresco y reintenta una vez. Un 401 del refresco borra el almacén y deja la sesión en «hay que entrar».
- Respetar `Retry-After` en un 429.
- `cerrarSesion` llama a `POST /auth/cerrar-sesion` con la cookie y borra memoria y `flutter_secure_storage`.
- Cada refresco con éxito sustituye el valor guardado por el de la `Set-Cookie` nueva.

La URL base sale de `String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8000')`.

### 6. Pantallas de cuenta, catálogo y lector

Orden de construcción, cada una contra la API real:

1. Login y registro. Comprobar que el JWT llega a memoria y que el valor de la cookie queda en el almacén seguro.
2. Catálogo: `GET /libros?desde=0&orden=titulo`, buscador `q`, filtro `idioma` con `GET /idiomas`, y «cargar más» con `siguiente`.
3. Ficha: `GET /libros/{id}` y la lista de capítulos.
4. Lector: `GET /libros/{id}/paginas/{n}`. Botones anterior y siguiente. Precargar la página vecina cabe en el cupo de 120 por minuto. No pedir el libro entero.
5. Cierre de sesión y reentrada en frío (matar el proceso y volver a abrir) para comprobar que `/auth/refrescar` renueva el JWT y que el valor guardado es el nuevo.

Estado local mínimo para «continuar leyendo»: el `id` del libro y el número de página en `shared_preferences`. Al abrir, `GET /libros?id=` recupera la ficha. Eso no pide un endpoint nuevo.

Las rutas de `MaterialApp` mandan a login cuando `preparar` no consigue sesión, y al catálogo cuando sí. El lector y el escáner cuelgan del catálogo.

### 7. Escáner y `.txt`

1. Declarar `CAMERA` y pedir el permiso al abrir la pantalla.
2. Abrir la cámara trasera, mostrar `CameraPreview` y capturar con `takePicture()`.
3. Pasar la ruta del JPEG a `InputImage.fromFilePath` y procesarla con `TextRecognitionScript.latin`.
4. Borrar el JPEG.
5. Mostrar el texto para que la persona lo corrija antes de guardar. El OCR de una página impresa se equivoca en nombres y en versos cortos.
6. Escribir UTF-8 en el directorio de documentos:

```dart
final dir = await getApplicationDocumentsDirectory();
final archivo = File('${dir.path}/$nombre.txt');
await archivo.writeAsString(texto);
```

`writeAsString` usa UTF-8. El nombre sale de un campo que escribe la persona (por ejemplo `004_la_celestina_012`), no de la ruta del JPEG.

7. Ofrecer compartir el archivo con `share_plus` para sacarlo del teléfono.
8. Si el usuario es admin y quiere publicarlo, juntar varias capturas en `paginas` y llamar `POST /libros` con metadatos escritos a mano. No enviar el JPEG.

### 8. Probar

- `flutter test` de los `fromJson` y del candado de refresco: dos llamadas concurrentes disparan un solo `POST /auth/refrescar`.
- Emulador contra `http://10.0.2.2:8000` con la API en Development (`CookieSegura: false`): login, un `GET /libros`, una página.
- Teléfono por USB con `adb reverse tcp:8000 tcp:8000`: matar la app, abrir y comprobar que el refresco renueva el JWT.
- Foto de una página impresa en español y un `.txt` que se abre con las palabras esperadas. El JPEG ya no está en el caché.
- Un lector que llama `POST /libros` recibe 403.
- Cinco login malos reciben 401 y el sexto sigue bloqueado unos 15 minutos.
- En release, la URL es HTTPS y el manifiesto principal no permite HTTP claro. El APK release abre la cámara y reconoce una página.

El emulador sirve para el cliente HTTP. Su cámara virtual es una prueba débil del OCR. El reconocimiento se da por bueno con una foto del teléfono, o con una imagen fija pasada a `InputImage.fromFilePath` mientras la cámara del emulador no enfoca una página.

## Qué se queda fuera de esta entrega

- No hay endpoint de imágenes ni de OCR en la API. Añadir uno subiría fotos de páginas ajenas al modelo (el documento guarda texto) y chocaría con el límite de 1 MB.
- No se abre Atlas desde el teléfono. `MONGO_URI` sigue solo en el `.env` del servidor y del pipeline.
- No se duplican las reglas de alta. Conteos, formato de `id` y rol admin los decide `CrearLibro`.
- Subrayados y progreso en la base siguen en `subrayados_por_usuario.md`. Hasta que esa API exista, la página actual vive en `shared_preferences`.
- El dev-api de Node (`dev-api/server.mjs`) es el puente viejo de solo lectura. La app apunta a `Biblioteca.Api`, no a ese proceso.
- No hay módulo Kotlin de aplicación. Cámara, ML Kit y almacenamiento entran por plugins.
- iOS queda fuera del primer corte. El proyecto se crea con `--platforms android`.

## Riesgos que conviene tener presentes

- **Cookie gastada.** Cada refresco invalida el valor anterior. Si el almacén seguro se queda con el viejo, el siguiente arranque falla y, fuera de los 30 segundos, revoca la familia. El fallo se ve en `POST /auth/refrescar` antes de tocar el OCR.
- **Refresco paralelo.** Dos 401 a la vez con la misma cookie dejan a la segunda llamada sin sesión. El `Future` único es parte del cliente, no un detalle de la pantalla.
- **`Set-Cookie` partido.** Leer `headers['set-cookie']` rompe el valor cuando la fecha lleva comas. Hay que usar `headersSplitValues`.
- **Calidad del OCR.** Una foto torcida, a media luz o con la rotación mal pasada devuelve texto sucio. `fromFilePath` conserva la rotación del JPEG. La pantalla de corrección evita publicar eso con `POST /libros`.
- **Ciclo de la cámara.** Dos controladores vivos, o un `takePicture()` antes de `initialize()`, fallan en Android con un error opaco del plugin. Un controlador por entrada a la pantalla, y `dispose()` al salir.
- **Cupo de autenticación por IP.** En una red compartida el límite de 5/min se agota pronto.
- **Primer build de Android.** Gradle descarga el SDK de las dependencias y ML Kit suma tamaño al APK. Eso no dice nada de la arquitectura de la API.
- **HTTP en release.** Un APK release contra `http://10.0.2.2` falla por la política de texto claro. El release apunta al HTTPS público.
