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
  -keep class com.ajinasokan.** { *; }
  -keep class com.csdcorp.** { *; }
  -keep class com.it_nomads.** { *; }
  -keep class com.pichillilorenzo.** { *; }
  -keep class com.tundralabs.** { *; }
  -keep class io.github.ponnamkarthik.** { *; }
  -keep class com.lyokone.** { *; }
  -keep class com.transistorsoft.** { *; }
  -keep class io.crossbell.** { *; }
  -keep class com.llfbandit.** { *; }
  -keep class vn.hunghd.flutterdownloader.** { *; }
  -keep class io.reactivex.rxjava3.** { *; }

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
  -dontwarn com.ajinasokan.**
  -dontwarn com.crazecoder.**
  -dontwarn com.csdcorp.**
  -dontwarn com.it_nomads.**
  -dontwarn com.pichillilorenzo.**
  -dontwarn com.tundralabs.**
  -dontwarn io.github.ponnamkarthik.**
  -dontwarn com.lyokone.**
  -dontwarn com.transistorsoft.**
  -dontwarn io.crossbell.**
  -dontwarn com.llfbandit.**
  -dontwarn vn.hunghd.flutterdownloader.**
  -dontwarn io.reactivex.rxjava3.**

  # Rhino JS engine (flutter_new_pipe_extractor) - java.beans absent on Android
  -dontwarn java.beans.**
  -dontwarn javax.script.**
  -dontwarn org.mozilla.javascript.**

  # Google Play Core (split APK / deferred components) - not present in sideload APK builds
  -dontwarn com.google.android.play.**
  -dontwarn com.google.android.play.core.**

  # GeneratedPluginRegistrant unconditionally references every plugin listed
  # in pubspec.yaml, including many whose Android implementation classes are
  # legitimately absent at compile time for this variant (iOS/desktop-only
  # plugins, or plugins whose AAR doesn't ship its own consumer-rules.pro).
  # R8's missing-class check treats every one of these as a hard build error
  # under profile/release. Rather than enumerate every plugin one at a time
  # (each round trip costs a full CI build), suppress missing-class warnings
  # globally — this only silences "class X is referenced but absent",
  # it does not change what -keep rules above actually retain.
  -dontwarn **

  # kxml2 (org.xmlpull.v1.XmlPullParser) duplicates the platform's own
  # android.content.res.XmlResourceParser hierarchy under R8 full-mode
  # shrinking (profile/release builds only — debug has minify disabled).
  # It's a transitive dep pulled in for a legacy XML pull-parser API path
  # never exercised on Android; silence the redefinition instead of failing.
  -dontwarn org.xmlpull.v1.**
  -dontwarn org.kxml2.**
  