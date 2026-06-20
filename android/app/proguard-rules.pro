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
-keep class com.watchtower.app.** { *; }

# ── Flutter plugin classes referenced by GeneratedPluginRegistrant ────────────
# R8 profile builds strip these if not kept explicitly
-keep class com.aaassseee.screen_brightness_android.** { *; }
-dontwarn com.aaassseee.**
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**
-keep class xyz.luan.** { *; }
-dontwarn xyz.luan.**
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**
-keep class dev.fluttercommunity.** { *; }
-dontwarn dev.fluttercommunity.**
-keep class com.baseflow.** { *; }
-dontwarn com.baseflow.**

# ── Inline Dalvik bridge ─────────────────────────────────────────────────────
# Keep NetworkHelper and cookie jar so extensions can find them via parent CL
-keep class eu.kanade.tachiyomi.network.** { *; }

# Keep all tachiyomi/aniyomi extension interface classes loaded via reflection
-keep class eu.kanade.tachiyomi.** { *; }
-keep class eu.kanade.aniyomi.** { *; }
-dontwarn eu.kanade.**

# DexClassLoader + reflection targets must not be renamed
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Kotlin coroutines (used in DalvikBridge)
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# OkHttp (provided to extensions via parent ClassLoader)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep classes accessed by reflection in DalvikBridge
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context);
}
