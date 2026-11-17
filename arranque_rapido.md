# Arranque rápido

Tres programas. Cada uno va en su propia terminal de PowerShell. La API tiene que estar escuchando antes de probar la web o el teléfono.

La API y el teléfono usan `http://127.0.0.1:8000`. No abras Kestrel en `0.0.0.0`. `dev-api` también ocupa el puerto 8000: si está encendido, apágalo.

El `.env` de la raíz del repositorio tiene que tener `MONGO_URI` y `JWT_CLAVE` (32 caracteres o más). No se pega en la app ni en el frontend.

## 1. API

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\backend\Biblioteca.Api
dotnet run --launch-profile http
```

Queda en `http://127.0.0.1:8000`. Deja esa terminal abierta.

Comprobar:

```powershell
curl http://127.0.0.1:8000/openapi/v1.json
```

Scalar, en desarrollo: `http://127.0.0.1:8000/scalar/v1`.

Dar admin a una cuenta que ya se registró (no levanta otro servidor):

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\backend\Biblioteca.Api
dotnet run -- asignar-rol correo@ejemplo.com admin
```

Después, en el teléfono, cierra sesión y vuelve a entrar. El rol nuevo no entra en el JWT que ya estaba en memoria.

## 2. Frontend web

La API del paso 1 tiene que seguir corriendo. Vite reenvía `/api` a `http://127.0.0.1:8000`.

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\frontend
npm install
npm run dev
```

Abre la URL que imprime Vite, normalmente `http://127.0.0.1:5173`.

## 3. App móvil por USB

La API del paso 1 tiene que seguir corriendo. El detalle de la primera vez (SDK, depuración USB, `flutter doctor`) está en `biblioteca_movil/instructivo_de_pruebas.md` y `biblioteca_movil/prueba_usb_primera_vez.md`.

En el teléfono: opciones de desarrollador y depuración USB. Acepta la huella del PC.

```powershell
adb devices
adb reverse tcp:8000 tcp:8000
adb reverse --list
```

`adb reverse --list` tiene que mostrar `tcp:8000 tcp:8000`. Si PowerShell no encuentra `adb`:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
```

Instalar y abrir la app en el teléfono, no en el emulador. `127.0.0.1` dentro del teléfono, gracias al reverse, es la API del PC.

```powershell
cd C:\Users\octavius\Desktop\INGENIERIA_7D\script_biblioteca\biblioteca_movil
flutter devices
flutter run -d <id-del-telefono> --dart-define=API_BASE=http://127.0.0.1:8000
```

Si solo hay un aparato Android conectado, basta `flutter run --dart-define=API_BASE=http://127.0.0.1:8000`.

Al desconectar el cable el reverse se pierde. Vuelve a ejecutar `adb reverse tcp:8000 tcp:8000`. No hace falta recompilar.

Prueba corta, con la API ya en marcha:

1. Regístrate o entra. La cuenta nueva es lectora.
2. **Inicio**, **Biblioteca** y **Ajustes** tienen que responder.
3. En Biblioteca, busca y abre **Filtros**. Cada tanda trae como mucho 20 libros.
4. Abre un libro y pasa de página.
5. En **Ajustes → Escanear una página**, el texto se guarda en el teléfono. No entra solo a Mongo.
6. Con una cuenta `admin`, **Ajustes → Publicar textos** manda las páginas con `POST /libros`.

## Qué falta de la rúbrica en la app móvil

Referencia: `biblioteca_movil/Avance3_Puntos_Aplicacion_Movil_y_Rubrica.md`. Se puede encender y probar. No cubre los 100 puntos.

| Punto | Estado | Qué ya está | Qué falta para el puntaje |
| --- | --- | --- | --- |
| 1. Interfaz (25) | Hecho en código | Barra Inicio, Biblioteca y Ajustes. Cuadrícula de portadas. Visor con tamaño, papel/noche e interlineado. | No se ha recorrido en un teléfono en esta sesión. |
| 2. Buscador (25) | Incompleto | `GET /libros` de 20 en 20. Filtros combinados: tipo (`temas`), idioma, extensión y palabra exacta en capítulos y páginas. | La rúbrica pide fecha e iglesia de origen. Esos campos no existen en el documento del libro, así que no hay filtro que los consulte. |
| 3. Módulo administrativo (25) | No está | Publicar un libro exige rol `admin`. | No hay dashboard ni indicadores del avance de digitalización de cada integrante frente a una meta. |
| 4. Conectividad cloud (25) | A medias | Un `http.Client` en el teléfono. Un `MongoClient` singleton en la API, con pool hacia Atlas y timeout de 8 s. Un fallo de red deja un texto y la app sigue abierta. | No hay un aviso propio para el timeout de Atlas ni una pantalla que muestre las peticiones concurrentes sin multiplicar los sockets a Atlas. |

El punto 3 y el cierre del punto 4 no están implementados. El arranque de arriba sirve para probar lo que ya corre.
