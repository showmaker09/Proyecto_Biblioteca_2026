# Primera prueba por cable USB

Guía para quien conecta un teléfono Android al PC por primera vez y prueba `biblioteca_movil` contra `Biblioteca.Api`. El cable no copia las hojas ni llena la memoria del teléfono: sirve para instalar la app y para que el teléfono hable con la API que está en el PC.

La API escucha solo en `http://127.0.0.1:8000`. El teléfono no ve ese puerto por la WiFi. `adb reverse` cruza el cable y hace que `127.0.0.1:8000` dentro del teléfono sea el puerto 8000 del PC.

Haz los pasos en orden. Deja abiertas las terminales que se indiquen.

## 1. Comprueba lo que ya tiene que estar en el PC

Abre PowerShell y ejecuta:

```powershell
flutter doctor
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" version
```

`flutter doctor` tiene que mostrar el Android toolchain en verde. Flutter de este proyecto es stable 3.35.7, con Dart 3.9.2, instalado en `C:\flutter`. `adb` ya viene con el SDK de Android, en `%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe`. PowerShell no lo encuentra si escribes solo `adb`, porque esa carpeta no está en el PATH. Por eso todos los comandos de `adb` usan la ruta completa.

Si `flutter doctor` no está en verde, instala Flutter y el SDK de Android antes de seguir. Esta guía no cambia el backend ni el front de Vite.

## 2. Instala el SDK de .NET que pide el backend

El proyecto, en `backend\global.json`, pide el SDK **10.0.403**. Un SDK 10.0 más viejo, por ejemplo el 10.0.103, no sirve. El comando se ejecuta en cualquier carpeta. Windows lo instala en `C:\Program Files\dotnet`, junto a los otros SDK. No lo copies dentro de `script_biblioteca` ni de `backend`: `dotnet run` no lo buscaría ahí.

```powershell
winget install --id Microsoft.DotNet.SDK.10 -e --version 10.0.403
```

Cierra esa terminal y abre otra. La sesión nueva es la que reconoce el SDK. Compruébalo:

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\backend
dotnet --version
```

Tiene que responder `10.0.403`.

## 3. Completa el `.env` de la raíz



Tiene que tener `MONGO_URI`, la cadena de Atlas de este proyecto, y `JWT_CLAVE`. La clave es la contraseña con la que el servidor firma los tokens. El teléfono no la conoce ni hay que escribirla en la app. Inventa una frase de al menos 32 caracteres:

```env
JWT_CLAVE=una-frase-larga-de-al-menos-32-caracteres
```

Sin esa línea, `dotnet run` se cierra antes de abrir el puerto. No hace falta quitar el JWT ni cambiar `RutaCookie`.

## 4. Arranca la API y déjala abierta

`dev-api` usa el mismo puerto 8000. Si está levantado, ciérralo. Para ver si el puerto está ocupado:

```powershell
Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
```

Si no imprime ninguna fila, el puerto está libre. Arranca la API:

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\backend\Biblioteca.Api
dotnet run --launch-profile http
```

Está bien cuando esa terminal se queda esperando y dice que escucha en `http://127.0.0.1:8000`. No la cierres. El perfil `http` deja el entorno en Development, que es el que permite la cookie de refresco por HTTP.

## 5. Prepara el teléfono

1. Ajustes, Acerca del teléfono. Toca siete veces el número de compilación hasta que se activen las opciones de desarrollador.
2. Opciones de desarrollador, activa Depuración USB.
3. Conecta un cable que pase datos, no uno que solo cargue.
4. En el aviso del teléfono, acepta la depuración de este PC.

Esos dos comandos no instalan la app, no abren la cámara y no escriben archivos en el teléfono:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" devices
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
```

`devices` tiene que mostrar el número de serie y la palabra `device`. Si dice `unauthorized`, acepta el aviso en la pantalla y vuelve a ejecutarlo. Si no aparece nada, prueba otro cable o otro puerto USB.

`reverse` crea el túnel. Los dos números son **8000**. Un `tcp:800` al final no llega a la API. El comando no reserva un buffer de fotos: es una regla de reenvío. Se pierde al desconectar el cable, al reiniciar el teléfono o al reiniciar el PC. Se vuelve a crear con el mismo comando, sin reinstalar la app.

## 6. Instala la app con Flutter

En otra terminal, con la API todavía abierta y el túnel ya creado:

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\biblioteca_movil
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
```

Eso compila la app, la instala en el teléfono y la abre. La primera vez Gradle descarga dependencias y ML Kit. Suele tardar entre 8 y 20 minutos. Si la red va lenta, puede pasar de eso. Las siguientes instalaciones, en el mismo teléfono, suelen tardar uno o dos minutos.

Está bien cuando la terminal muestra, en este orden, el APK construido, `Installing`, `Syncing files to device` y `Flutter run key commands`. Deja esa terminal abierta durante esta primera prueba. `q` cierra la conexión de depuración. La app queda instalada.

En el teléfono se abre Biblioteca. Abajo del login, en letras pequeñas, tiene que leerse `API http://127.0.0.1:8000`. Esa línea solo muestra la dirección. No prueba todavía que el cable lleve la petición.

En un teléfono físico, `10.0.2.2` no es el PC. Si el texto muestra esa dirección, cierra la app y vuelve a lanzarla con el `--dart-define` de arriba, después del `reverse`.

## 7. Crea la cuenta

No pulses **Entrar**. Todavía no hay un usuario. **Crear cuenta**, en el login, solo abre el formulario. Escribe nombre, correo y una contraseña de 10 a 128 caracteres, y pulsa el **Crear cuenta** de ese formulario. Ese botón llama a `POST /auth/registro`. La cuenta entra como lectora. El rol `admin` no se elige aquí.

Si el alta funciona, la app pasa sola al catálogo. Ahí el túnel y la API están bien.

Si aparece «No se pudo hablar con la biblioteca», el teléfono no recibió respuesta. El texto está en `lib\nucleo\navegacion.dart` y se muestra cuando falla la conexión, no cuando la API rechaza el correo o la contraseña. La causa habitual es que el túnel se perdió. Repite los dos comandos de `adb` del paso 5 y pulsa **Crear cuenta** otra vez. No hace falta volver a ejecutar `flutter run` si el login sigue diciendo `API http://127.0.0.1:8000` y la terminal de la API sigue abierta.

## 8. Prueba el escáner

En el catálogo, el icono del escáner está en la barra superior. El lector puede usarlo. Publicar el texto en la base es otro paso y solo aparece con rol `admin`.

1. Acepta el permiso de cámara. Tienes que ver la vista en vivo y el botón **Capturar página**.
2. Encuadra una hoja en español, con luz pareja y el texto llenando la imagen. Pulsa **Capturar página**.
3. La pantalla dice **Un momento…**. El teléfono lee las letras y borra la foto. La hoja no se envía a la API.
4. Aparece el texto y la frase «Corrige el texto antes de guardarlo. La foto ya se borró.» Corrige lo que haya salido mal.
5. En **Nombre del archivo** escribe algo como `004_la_celestina_012`. Solo letras, números, guion y guion bajo, hasta 80 caracteres.
6. Pulsa **Guardar texto**. Tiene que aparecer «Guardado en el teléfono.» Entonces se activa **Compartir**. **Otra página** vuelve a la cámara.

La prueba está bien si el texto corresponde a la hoja, aparece «Guardado en el teléfono» y el archivo existe en el teléfono. Con el cable conectado, cambia el nombre del `cat` por el que hayas usado:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" shell run-as com.biblioteca.biblioteca_movil ls app_flutter
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" shell run-as com.biblioteca.biblioteca_movil cat app_flutter/004_la_celestina_012.txt
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" shell run-as com.biblioteca.biblioteca_movil ls cache
```

En `app_flutter` tiene que estar el `.txt`. En `cache` no tiene que quedar un `CAP….jpg` de esa captura. Puede haber otros archivos de caché de Flutter. `run-as` solo funciona con la app de depuración que instaló `flutter run`.

Si dice que no hay permiso de cámara, actívalo en Ajustes, Aplicaciones, Biblioteca, Permisos, Cámara. El catálogo sigue disponible.

## 9. La siguiente vez

No repitas la instalación del SDK ni `flutter run` si no cambiaste código.

1. Abre la terminal de la API con `dotnet run --launch-profile http` y espera `http://127.0.0.1:8000`.
2. Conecta el cable y acepta la depuración si el teléfono lo pide.
3. Vuelve a ejecutar `adb devices` y `adb reverse tcp:8000 tcp:8000`.
4. Abre Biblioteca desde el icono del teléfono.

Esa instalación ya lleva la dirección `http://127.0.0.1:8000`. Sin la API y sin el `reverse`, al crear la cuenta o al entrar vuelve el aviso de que no se pudo hablar con la biblioteca.

`flutter run` hace falta otra vez solo si cambiaste el código, si desinstalaste la app, o si la línea del login no dice `http://127.0.0.1:8000`.
