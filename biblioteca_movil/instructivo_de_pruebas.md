# Instructivo de pruebas

Pasos para comprobar `biblioteca_movil` contra `Biblioteca.Api` tal como está hoy. La app no abre Mongo y no cambia el backend. El OCR se prueba en un teléfono Android real: el emulador sirve para el cliente HTTP y su cámara virtual no enfoca una página impresa.

Hay tres caminos. El primero no necesita aparato. El segundo es el cable USB. El tercero es la depuración inalámbrica de Android, que también usa `adb reverse` y deja Kestrel en `127.0.0.1`.

Quien conecta el teléfono por primera vez puede seguir [prueba_usb_primera_vez.md](prueba_usb_primera_vez.md): instala el SDK 10.0.403, arranca la API, abre el túnel y prueba el escáner.

## 0. Qué tiene que estar listo

En una terminal de PowerShell:

```powershell
flutter doctor
```

Android toolchain tiene que salir en verde antes de instalar la app. Flutter de este proyecto: stable 3.35.7, Dart 3.9.2.

`adb` vive en el SDK de Android:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" version
```

Si ese comando responde, puedes usar `adb` en el resto de los pasos. Si PowerShell no lo encuentra, llama al `.exe` con esa ruta.

La API escucha solo en loopback. Desde la carpeta del proyecto de C#:

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\backend\Biblioteca.Api
dotnet run --launch-profile http
```

Tiene que quedar en `http://127.0.0.1:8000`, con `ASPNETCORE_ENVIRONMENT=Development`. Ese perfil ya trae `CookieSegura: false`. El `.env` de la raíz del repositorio tiene que tener `MONGO_URI` y `JWT_CLAVE`. No hace falta tocar `RutaCookie`: la app manda `biblioteca_refresco` a mano.

`dev-api` también usa el puerto 8000. Si está levantado, apágalo. Para ver quién ocupa el puerto:

```powershell
Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
```

Deja esa terminal de `dotnet run` abierta mientras pruebas.

En el teléfono, la dirección depende del camino:

| Camino | `API_BASE` |
|---|---|
| Emulador | `http://10.0.2.2:8000` (es el valor por defecto en depuración) |
| USB o depuración inalámbrica, con `adb reverse` | `http://127.0.0.1:8000` |
| Release | `https://…` público. Un APK release no llama a una IP de desarrollo |

En un teléfono físico, `10.0.2.2` no es el PC. Hay que pasar `API_BASE` a mano.

## 1. Pruebas automáticas, sin teléfono

Desde `biblioteca_movil`:

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\biblioteca_movil
flutter test
flutter analyze
```

Tienen que pasar los ocho tests: el JSON del contrato (`_id`, `siguiente: null`), la cookie con una fecha que lleva comas, el candado de un solo `POST /auth/refrescar` cuando dos llamadas reciben 401 a la vez, el borrado del almacén si el refresco falla, y el nombre de archivo que no puede salirse del directorio de la app.

Esto no enciende la cámara ni habla con Atlas.

## 2. Emulador (cliente HTTP)

Sirve para login, catálogo y lector. El reconocimiento de una página impresa se deja para el teléfono.

1. Arranca un emulador desde Android Studio, o con `flutter emulators` y `flutter emulators --launch <id>`.
2. Espera a que aparezca en `flutter devices`.
3. Con la API ya en marcha:

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\biblioteca_movil
flutter run --dart-define=API_BASE=http://10.0.2.2:8000
```

4. En la app, crea una cuenta (contraseña de 10 a 128 caracteres). La cuenta entra como lectora y la pantalla pasa al catálogo.
5. Busca un título, cambia el idioma, abre un libro y pasa una página adelante y atrás.
6. Cierra sesión y vuelve a entrar con el mismo correo.

La primera compilación de Android descarga Gradle y ML Kit. Puede tardar varios minutos. El permiso de cámara, si el emulador no tiene cámara, muestra un aviso y el catálogo sigue usable.

## 3. Teléfono por USB

Este es el camino para el OCR. La API sigue en `127.0.0.1` del PC. `adb reverse` hace que `127.0.0.1:8000` dentro del teléfono sea ese Kestrel. No se abre el puerto 8000 a la WiFi del salón, así que el límite de 5 login por minuto y por IP no se comparte con otros aparatos.

### Preparar el teléfono

1. Ajustes, Acerca del teléfono. Toca siete veces el número de compilación hasta que se activen las opciones de desarrollador.
2. Opciones de desarrollador, activa Depuración USB.
3. Conecta el cable. En el aviso del teléfono, acepta la depuración de este PC (marca «permitir siempre» si quieres).
4. Comprueba el aparato:

```powershell
adb devices
```

Tiene que salir una línea con el número de serie y `device`. Si dice `unauthorized`, acepta el aviso en la pantalla del teléfono y vuelve a ejecutar el comando. Si no aparece nada, prueba otro cable (tiene que llevar datos, no solo carga) y otro puerto USB.

### Túnel y arranque

Con la API escuchando en el PC:

```powershell
adb reverse tcp:8000 tcp:8000
adb reverse --list
```

La lista tiene que mostrar `host-8000 tcp:8000`.

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\biblioteca_movil
flutter devices
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
```

Si hay emulador y teléfono a la vez, elige el teléfono:

```powershell
flutter run -d <id-del-telefono> --dart-define=API_BASE=http://127.0.0.1:8000
```

El `<id>` es el que imprime `flutter devices`. En la pantalla de login, en depuración, se ve la línea `API http://127.0.0.1:8000`.

`adb reverse` se pierde al desconectar el cable o al reiniciar `adb`. Si la app deja de hablar con la biblioteca, vuelve a ejecutar `adb reverse tcp:8000 tcp:8000` sin recompilar.

## 4. Alternativa sin cable: depuración inalámbrica

Sirve cuando el cable falla o quieres dejar el teléfono en la mano para encuadrar una página. El teléfono y el PC tienen que verse en la red local solo para el puerto de `adb`. La API no se publica: el tráfico de la app sigue yendo a `127.0.0.1:8000` del teléfono y `adb reverse` lo entrega en el loopback del PC.

Hace falta Android 11 o superior.

1. Teléfono y PC en la misma WiFi.
2. Opciones de desarrollador, activa Depuración inalámbrica.
3. Entra en Depuración inalámbrica y toca «Vincular dispositivo con código de vinculación». Anota la IP, el puerto de vinculación y el código de seis dígitos. Ese puerto es el de emparejar, y caduca.
4. En la misma pantalla, fuera del cuadro de vinculación, anota la IP y el puerto de depuración. Ese puerto es el de conectar, y es distinto.

```powershell
adb pair 192.168.1.50:37123
```

Escribe el código cuando lo pida. Luego:

```powershell
adb connect 192.168.1.50:41555
adb devices
adb reverse tcp:8000 tcp:8000
```

Sustituye la IP y los puertos por los de tu teléfono. `adb devices` tiene que mostrar `IP:puerto` con estado `device`.

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\biblioteca_movil
flutter run -d 192.168.1.50:41555 --dart-define=API_BASE=http://127.0.0.1:8000
```

A partir de aquí los pasos de la app son los mismos que por USB. Si el túnel se cae, repite `adb connect` y `adb reverse`.

### Por qué no se usa la IP del PC como primer plan

Apuntar la app a `http://192.168.x.x:8000` exige que Kestrel escuche en `0.0.0.0` y que el firewall de Windows abra el puerto 8000. Eso deja el login en la red del salón: 5 intentos por minuto entre todos los teléfonos que salgan con la misma IP, y 5 fallos bloquean la cuenta 15 minutos. Este instructivo no cambia `launchSettings.json`. El cable y la depuración inalámbrica evitan ese cambio.

## 5. Recorrido en la app

Hazlo en el emulador o en el teléfono. En el teléfono, el escáner es el que cuenta.

1. Crear cuenta. Nombre, correo y contraseña de al menos 10 caracteres. La app entra al catálogo sin pedir el login otra vez.
2. Catálogo. El saludo muestra el nombre. Busca por título o autor, cambia el orden y el idioma, y pulsa «Cargar más» si hay más de 20 libros.
3. Ficha. Abre un libro. Se ven autor, idioma, páginas y capítulos. «Leer» abre la página 1.
4. Lector. Avanza y retrocede. Cada pulsación pide una sola página. Al volver a la ficha, el botón ofrece seguir en la página donde te quedaste.
5. Cerrar sesión. El icono de salir vuelve al login. Entrar de nuevo con la misma cuenta llega otra vez al catálogo.

### Sesión en frío

El JWT dura 15 minutos y no se guarda. Lo que se guarda es el valor de `biblioteca_refresco`. Cada refresco invalida el valor anterior, así que hay que comprobar que la app guardó el nuevo.

1. Entra y llega al catálogo.
2. Cierra la app del todo. En el teléfono: recents y deslizarla fuera. O, con el cable o la depuración inalámbrica:

```powershell
adb shell am force-stop com.biblioteca.biblioteca_movil
```

Si `flutter run` seguía enganchado, esa terminal dirá que perdió la conexión. El APK de depuración sigue instalado.

3. Espera más de 30 segundos. Si el valor guardado fuera el viejo, el servidor revoca la familia de refresco y la próxima apertura pediría login.
4. Abre Biblioteca desde el cajón de aplicaciones. Tiene que entrar al catálogo sin pedir la contraseña.
5. Repite el cierre, espera otros 30 segundos y ábrela otra vez. Si vuelve a entrar sola, el valor nuevo quedó guardado.

Para enganchar otra vez los logs:

```powershell
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
```

En el emulador usa `http://10.0.2.2:8000` en ese comando.

## 6. OCR de una página impresa

En el teléfono, con luz pareja y la página llenando el marco:

1. En el catálogo, el icono del escáner.
2. Acepta el permiso de cámara cuando Android lo pida.
3. Encuadra una página en español y pulsa «Capturar página».
4. La pantalla de corrección dice que la foto ya se borró. Corrige nombres y versos cortos.
5. En el nombre escribe algo como `004_la_celestina_012` (letras, números, guion o guion bajo, sin espacios ni barras).
6. Pulsa «Guardar texto» y luego «Compartir» si quieres sacar el `.txt` del teléfono.

Comprueba el archivo y que el JPEG temporal ya no está. `run-as` solo funciona con la app de depuración que instaló `flutter run`:

```powershell
adb shell run-as com.biblioteca.biblioteca_movil ls app_flutter
adb shell run-as com.biblioteca.biblioteca_movil cat app_flutter/004_la_celestina_012.txt
adb shell run-as com.biblioteca.biblioteca_movil ls cache
```

`app_flutter` es el directorio privado de documentos. Ahí tiene que estar el `.txt` en UTF-8, con las palabras de la página. En `cache` no tiene que quedar un `CAP….jpg` de esa captura: la cámara lo escribe ahí y el OCR lo borra al terminar. Puede haber otros archivos de caché de Flutter; lo que no debe quedar es el JPEG de la página.

Si el permiso se negó, la pantalla lo dice y el catálogo sigue disponible. Se activa en Ajustes, Aplicaciones, Biblioteca, Permisos, Cámara.

## 7. Publicar, solo admin

Un lector no ve el icono de publicar. Si abre la ruta, la pantalla explica que un lector recibe 403 y no envía el libro.

Para ver el icono, en otra terminal (el servidor puede seguir corriendo):

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\backend\Biblioteca.Api
dotnet run -- asignar-rol persona@correo.com admin
```

Cierra sesión en el teléfono y entra de nuevo. El icono de publicar aparece en el catálogo. Ahí se eligen los `.txt` ya guardados, en orden de página, y se escriben id, título, autor e idioma. Se envía texto. La foto no sale del teléfono.

Para ver el 403 sin cambiar de rol, desde el PC, con una cuenta lectora:

```powershell
$sesion = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8000/auth/login -ContentType application/json -Body '{"correo":"lector@ejemplo.com","contrasena":"una-clave-de-prueba"}'
try {
  Invoke-WebRequest -Method Post -Uri http://127.0.0.1:8000/libros -Headers @{ Authorization = "Bearer $($sesion.token_acceso)" } -ContentType application/json -Body '{"id":"099_prueba","titulo":"Prueba","autor":"Nadie","idioma":"es","paginas":["hola"]}'
} catch {
  $_.Exception.Response.StatusCode.value__
}
```

La respuesta es 403. No crea el libro.

## 8. Cinco contraseñas mal

Usa una cuenta de prueba, no la cuenta con la que vas a seguir leyendo. Escribe mal la contraseña cinco veces. Cada una responde como si el correo no existiera. La sexta, aunque la contraseña sea la buena, sigue rechazada unos 15 minutos. El límite de login es 5 por minuto y por IP: si los haces muy seguidos, antes puede aparecer un 429.

## 9. Release

Un `flutter run` normal es depuración: el manifiesto de `android/app/src/debug` permite HTTP. El manifiesto principal, el que entra en el APK release, no tiene `usesCleartextTraffic`.

Para un APK que vaya a un servidor público:

```powershell
flutter build apk --dart-define=API_BASE=https://tu-dominio
```

Sin esa URL en HTTPS, la app de release no llama a `http://10.0.2.2` ni a `http://127.0.0.1`. No hace falta generar el APK para dar por buena la prueba de desarrollo.

## Si algo falla

| Lo que se ve | Qué revisar |
|---|---|
| La app no conecta y el login muestra la IP `10.0.2.2` en un teléfono | Vuelve a lanzar con `--dart-define=API_BASE=http://127.0.0.1:8000` después de `adb reverse`. |
| Conexión rechazada justo después de desconectar el cable | `adb reverse tcp:8000 tcp:8000` otra vez. |
| El catálogo no carga y `dev-api` está corriendo | Apaga `dev-api`. El puerto 8000 es de `Biblioteca.Api`. |
| Al abrir la app por segunda vez pide login | El refresco no guardó la cookie nueva, o pasaron más de 30 segundos con el valor viejo. Entra de nuevo. Si se repite, el fallo está en el arranque, antes de probar el OCR. |
| «Sin permiso de cámara» | Ajustes del teléfono, permisos de Biblioteca. |
| El texto del OCR sale sucio | Más luz, página plana, que llene el marco. Corrige en la pantalla antes de guardar. |
| Gradle se queda mucho rato la primera vez | Es la descarga del SDK de Android y de ML Kit. No indica un fallo de la API. |
| `adb devices` vacío | Cable de datos, depuración USB aceptada, o `adb kill-server` y luego `adb devices`. |
