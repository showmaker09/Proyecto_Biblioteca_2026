package com.biblioteca.biblioteca_movil

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}
