package com.watchtower.app

  import androidx.annotation.NonNull
  import libmtorrentserver.Libmtorrentserver
  import io.flutter.embedding.engine.FlutterEngine
  import io.flutter.plugin.common.MethodChannel
  import io.flutter.plugin.common.StandardMethodCodec
  import io.flutter.embedding.android.FlutterFragmentActivity
  import androidx.core.content.FileProvider
  import android.content.Intent
  import android.os.Build
  import android.net.Uri
  import java.io.File

  class MainActivity: FlutterFragmentActivity() {

      override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
          super.configureFlutterEngine(flutterEngine)
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.libmtorrentserver",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "start" -> {
                      val config = call.argument<String>("config")
                      try {
                          val port = Libmtorrentserver.start(config)
                          result.success(port)
                      } catch (e: Exception) {
                          result.error("ERROR", e.message, null)
                      }
                  }
                  else -> {
                      result.notImplemented()
                  }
              }
          }

          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.apk_install",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "installApk" -> {
                      val filePath = call.argument<String>("filePath")
                      installApk(filePath)
                      result.success(null)
                  }
                  else -> {
                      result.notImplemented()
                  }
              }
          }

          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.package_scanner",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "getInstalledMihonExtensions" -> {
                      try {
                          val pm = packageManager
                          val allPkgs = pm.getInstalledPackages(0)
                          val mihonPkgs = allPkgs
                              .filter { info ->
                                  info.packageName.startsWith("eu.kanade.tachiyomi.extension.") ||
                                  info.packageName.startsWith("eu.kanade.tachiyomi.animeextension.")
                              }
                              .mapNotNull { info ->
                                  try {
                                      val appInfo = pm.getApplicationInfo(info.packageName, 0)
                                      mapOf(
                                          "pkg"         to info.packageName,
                                          "versionName" to (info.versionName ?: ""),
                                          "sourceDir"   to (appInfo.sourceDir ?: "")
                                      )
                                  } catch (_: Exception) { null }
                              }
                          result.success(mihonPkgs)
                      } catch (e: Exception) {
                          result.error("SCAN_ERROR", e.message, null)
                      }
                  }
                  else -> result.notImplemented()
              }
          }
      }

      private fun installApk(filePath: String?) {
          if (filePath == null) return
          val file = File(filePath)
          val intent = Intent(Intent.ACTION_VIEW)
          intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
          val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
              intent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
              FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
          } else {
              Uri.fromFile(file)
          }
          intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
          startActivity(intent)
      }
  }
  