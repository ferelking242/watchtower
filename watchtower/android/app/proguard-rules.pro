# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Dart/Flutter JNI
-keep class com.google.** { *; }
-dontwarn com.google.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# Isar
-keep class dev.isar.** { *; }
-dontwarn dev.isar.**

# OkHttp / Networking
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Serialization
-keepattributes Signature
-keepattributes *Annotation*

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Watchtower
-keep class com.kodjodevf.watchtower.** { *; }
