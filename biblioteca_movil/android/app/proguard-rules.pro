# Reglas para R8 en compilación release:
# google_mlkit_text_recognition solo se usa con alfabeto latino (TextRecognitionScript.latin).
# Los módulos opcionales de chino, devanagari, japonés y coreano no se empaquetan en el APK.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
