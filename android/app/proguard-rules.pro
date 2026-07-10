# Flutter core
  -keep class io.flutter.app.** { *; }
  -keep class io.flutter.plugin.** { *; }
  -keep class io.flutter.util.** { *; }
  -keep class io.flutter.view.** { *; }
  -keep class io.flutter.** { *; }
  -keep class io.flutter.plugins.** { *; }
  -keep class io.flutter.embedding.** { *; }

  # Flutter plugins
  -keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
  -keep class * implements io.flutter.plugin.common.PluginRegistry$RegistrarGetter { *; }

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

  # Rhino JS engine (flutter_new_pipe_extractor) - java.beans absent on Android
  -dontwarn java.beans.**
  -dontwarn javax.script.**
  -dontwarn org.mozilla.javascript.**

  # Google Play Core (split APK / deferred components) - not present in sideload APK builds
  -dontwarn com.google.android.play.**
  -dontwarn com.google.android.play.core.**

  # kxml2 (org.xmlpull.v1.XmlPullParser) duplicates the platform's own
  # android.content.res.XmlResourceParser hierarchy under R8 full-mode
  # shrinking (profile/release builds only — debug has minify disabled).
  # It's a transitive dep pulled in for a legacy XML pull-parser API path
  # never exercised on Android; silence the redefinition instead of failing.
  -dontwarn org.xmlpull.v1.**
  -dontwarn org.kxml2.**
  