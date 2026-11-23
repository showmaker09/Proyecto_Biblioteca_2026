package com.biblioteca.biblioteca_movil

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permisoPendiente: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // El lector pide que la pantalla no se apague mientras se lee
        // (lib/nucleo/pantalla_encendida.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "biblioteca/pantalla")
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    "mantenerEncendida" -> {
                        if (llamada.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        resultado.success(null)
                    }
                    else -> resultado.notImplemented()
                }
            }
        // El escáner guarda cada libro en Documentos/Biblioteca para que se vea
        // en el gestor de archivos (lib/funciones/escaner/carpeta_publica.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "biblioteca/almacen")
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    "carpetaDocumentos" -> resultado.success(carpetaDocumentos())
                    "pedirPermisoEscritura" -> pedirPermisoEscritura(resultado)
                    "indexar" -> {
                        val rutas = llamada.argument<List<String>>("rutas").orEmpty()
                        if (rutas.isNotEmpty()) {
                            MediaScannerConnection.scanFile(this, rutas.toTypedArray(), null, null)
                        }
                        resultado.success(null)
                    }
                    else -> resultado.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun carpetaDocumentos(): String =
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS).absolutePath

    // Hasta Android 10 escribir en Documentos pide permiso. Desde Android 11
    // cada app crea sus propios archivos ahí sin pedir nada.
    private fun pedirPermisoEscritura(resultado: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        ) {
            resultado.success(true)
            return
        }
        permisoPendiente?.success(false)
        permisoPendiente = resultado
        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), CODIGO_PERMISO)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CODIGO_PERMISO) return
        val concedido = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        permisoPendiente?.success(concedido)
        permisoPendiente = null
    }

    private companion object {
        const val CODIGO_PERMISO = 4107
    }
}
