# ML Kit full component keep rules
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep interface com.google.mlkit.** { *; }
-keep class * implements com.google.mlkit.common.internal.model.ModelLoader { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }

# Google Play Services & Drive APIs
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.api.services.drive.** { *; }
-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.client.**
-dontwarn com.google.api.services.drive.**
