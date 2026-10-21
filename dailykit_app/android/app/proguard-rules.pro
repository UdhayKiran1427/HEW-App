# ML Kit text recognition optional language recognizer rules
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google_mlkit_text_recognition.**
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Google Sign In & Drive APIs
-keep class com.google.api.services.drive.** { *; }
-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.client.**
-dontwarn com.google.api.services.drive.**
