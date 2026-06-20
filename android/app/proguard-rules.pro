# Flutter core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── Flutter plugins — keep ALL FlutterPlugin implementations ─────────────────
# R8 in profile mode strips plugin classes not directly referenced;
# GeneratedPluginRegistrant.registerWith() loads them reflectively.
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$RegistrarGetter { *; }

# Blanket keep for known Flutter plugin vendor packages
-keep class com.aaassseee.** { *; }
-keep class com.alexmercerind.** { *; }
-keep class com.eyedeadevelopment.** { *; }
-keep class com.ryanheise.** { *; }
-keep class xyz.luan.** { *; }
-keep class com.dexterous.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keep class com.baseflow.** { *; }
-keep class io.github.** { *; }
-keep class com.tekartik.** { *; }
-keep class io.wazo.** { *; }
-keep class net.pento.** { *; }
-keep class com.jhomlala.** { *; }
-keep class vn.hunghd.** { *; }
-keep class com.mr.flutter.** { *; }
-keep class com.bluechilli.** { *; }
-keep class com.hellobike.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
-keep class com.pichillilorenzo.** { *; }
-keep class com.getkeepsafe.** { *; }
-keep class com.crazecoder.** { *; }

# Suppress R8 warnings for all plugin packages (they exist at runtime)
-dontwarn com.aaassseee.**
-dontwarn com.alexmercerind.**
-dontwarn com.eyedeadevelopment.**
-dontwarn com.ryanheise.**
-dontwarn xyz.luan.**
-dontwarn com.dexterous.**
-dontwarn dev.fluttercommunity.**
-dontwarn com.baseflow.**
-dontwarn io.github.**
-dontwarn com.tekartik.**
-dontwarn io.wazo.**
-dontwarn net.pento.**
-dontwarn com.jhomlala.**
-dontwarn vn.hunghd.**
-dontwarn com.mr.flutter.**
-dontwarn com.bluechilli.**
-dontwarn com.hellobike.**
-dontwarn com.pichillilorenzo.**
-dontwarn com.getkeepsafe.**
-dontwarn com.crazecoder.**

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
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Serialization
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Watchtower
-keep class com.kodjodevf.watchtower.** { *; }
-keep class com.watchtower.app.** { *; }

# ── Inline Dalvik bridge ─────────────────────────────────────────────────────
-keep class eu.kanade.tachiyomi.network.** { *; }
-keep class eu.kanade.tachiyomi.** { *; }
-keep class eu.kanade.aniyomi.** { *; }
-dontwarn eu.kanade.**

# Kotlin coroutines
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Keep classes accessed by reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context);
}
