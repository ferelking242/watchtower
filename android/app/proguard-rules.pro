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
  # app_links: keep the plugin class itself explicitly (name AND members),
  # not just relying on the generic com.llfbandit.** keep below — this plugin
  # is only ever referenced reflectively from GeneratedPluginRegistrant, so a
  # broad "-keep class X { *; }" without -keepnames can still let R8/shrinkResources
  # drop it if reachability analysis doesn't see the reflective call site.
  -keep class com.llfbandit.app_links.** { *; }
  -keepnames class com.llfbandit.app_links.** { *; }
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

  # Shizuku (direct API calls from MainActivity, but the AIDL-generated
  # rikka.shizuku.* stubs are invoked through the binder/Parcelable machinery
  # reflectively — R8 has previously mis-shrunk exactly this pattern for other
  # plugins in this project, causing a crash the instant MainActivity's class
  # initializer runs, before the first Flutter frame — i.e. stuck on the
  # native splash screen forever with no logs/crash report reaching Flutter.
  -keep class rikka.shizuku.** { *; }
  -keepnames class rikka.shizuku.** { *; }
  -dontwarn rikka.shizuku.**

  # libmtorrentserver: native/AAR bridge (Libmtorrentserver.start is called
  # directly from Kotlin, but the AAR's own JNI bindings resolve classes by
  # name from native code, which R8 cannot see as a reachable reference).
  -keep class libmtorrentserver.** { *; }
  -dontwarn libmtorrentserver.**

  # DalvikBridge calls Kotlin coroutines suspend functions and hands OkHttp
  # instances to extension APKs entirely via reflection (see build.gradle
  # comments) — R8 cannot trace those call sites, so both libraries need an
  # explicit keep or they can be stripped/renamed even though they still work
  # when this app's own code calls them directly.
  -keep class kotlinx.coroutines.** { *; }
  -dontwarn kotlinx.coroutines.**
  -keep class okhttp3.** { *; }
  -dontwarn okhttp3.**

  # This app's own MainActivity/DalvikBridge/glance widget code is loaded via
  # manifest components and reflection from extension APKs (DexClassLoader) —
  # keep it verbatim so extension APKs can resolve it by name at runtime.
  -keep class com.watchtower.app.** { *; }
  -keep class com.kodjodevf.watchtower.** { *; }

  # kxml2 (org.xmlpull.v1.XmlPullParser) duplicates the platform's own
  # android.content.res.XmlResourceParser hierarchy under R8 full-mode
  # shrinking (profile/release builds only — debug has minify disabled).
  # It's a transitive dep pulled in for a legacy XML pull-parser API path
  # never exercised on Android; silence the redefinition instead of failing.
  -dontwarn org.xmlpull.v1.**
  -dontwarn org.kxml2.**
  