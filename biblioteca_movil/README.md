# biblioteca_movil

Cliente Android en Flutter. Lee y escribe solo por `Biblioteca.Api`. No abre Mongo, no entra en `Biblioteca.slnx` y no cambia el backend ni el front de Vite.

La cámara y el OCR ocurren en el teléfono. Se guarda un `.txt` en el directorio privado de la app y se borra el JPEG. Publicar un libro (`POST /libros`) solo se ofrece si el rol es `admin`.

## Arranque

La API tiene que estar en marcha en Development (`CookieSegura: false`), en `http://127.0.0.1:8000`. No hace falta cambiar `RutaCookie`: la app manda `biblioteca_refresco` a mano.

```powershell
cd biblioteca_movil
flutter run --dart-define=API_BASE=http://10.0.2.2:8000
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
flutter run --dart-define=API_BASE=http://192.168.1.20:8000
```

- Emulador: `10.0.2.2` llega al loopback del PC. Es el valor por defecto en depuración.
- Teléfono por USB: `adb reverse tcp:8000 tcp:8000` y `http://127.0.0.1:8000`. Es el camino para probar el OCR.
- Teléfono solo por WiFi: la API tendría que escuchar en la LAN. Ese cambio no forma parte de esta app, porque abre el puerto a la red y el límite de login es de 5 intentos por minuto y por IP.

En depuración el manifiesto permite HTTP. En release no. Un APK de release sin `API_BASE` en HTTPS no llama a una IP de desarrollo:

```powershell
flutter build apk --dart-define=API_BASE=https://tu-dominio
```

`dev-api` también usa el puerto 8000. Si ese proceso está levantado, el teléfono no habla con `Biblioteca.Api`.

Los pasos para probarla, en el emulador, por USB o por depuración inalámbrica, están en [instructivo_de_pruebas.md](instructivo_de_pruebas.md). La primera vez con cable, de la instalación del SDK al escáner, está en [prueba_usb_primera_vez.md](prueba_usb_primera_vez.md).
