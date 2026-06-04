package com.watchtower.app

  import android.app.PendingIntent
  import android.app.PictureInPictureParams
  import android.content.BroadcastReceiver
  import android.content.Context
  import android.content.Intent
  import android.content.IntentFilter
  import android.content.pm.PackageInstaller
  import android.content.pm.PackageManager
  import android.net.Uri
  import android.os.Build
  import androidx.annotation.NonNull
  import androidx.core.content.ContextCompat
  import androidx.core.content.FileProvider
  import io.flutter.embedding.android.FlutterFragmentActivity
  import io.flutter.embedding.engine.FlutterEngine
  import io.flutter.plugin.common.EventChannel
  import io.flutter.plugin.common.MethodChannel
  import io.flutter.plugin.common.StandardMethodCodec
  import libmtorrentserver.Libmtorrentserver
  import rikka.shizuku.Shizuku
  import java.io.File

  class MainActivity : FlutterFragmentActivity() {

      // ── Mihon constants (mirrors ExtensionLoader.kt) ──────────────────────
      companion object {
          private const val EXT_FEATURE     = "tachiyomi.extension"
          private const val PRIVATE_EXT_DIR = "exts"
          private const val PRIVATE_EXT_EXT = ".ext"
          private const val SHIZUKU_CODE    = 1042

          @Suppress("DEPRECATION")
          private val PKG_FLAGS =
              android.content.pm.PackageManager.GET_CONFIGURATIONS or
              android.content.pm.PackageManager.GET_META_DATA
      }

      // ── Extension watcher ────────────────────────────────────────────────
      private var extEventSink: EventChannel.EventSink? = null

      private val extReceiver = object : BroadcastReceiver() {
          override fun onReceive(ctx: Context, intent: Intent?) {
              val pkg   = intent?.data?.schemeSpecificPart ?: return
              val event = when (intent.action) {
                  Intent.ACTION_PACKAGE_ADDED    -> "added"
                  Intent.ACTION_PACKAGE_REPLACED -> "replaced"
                  Intent.ACTION_PACKAGE_REMOVED  -> "removed"
                  else -> return
              }
              if (event == "removed") {
                  extEventSink?.success(mapOf("event" to event, "pkg" to pkg))
                  return
              }
              try {
                  val pm = applicationContext.packageManager
                  val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                      pm.getPackageInfo(pkg,
                          android.content.pm.PackageManager.PackageInfoFlags.of(PKG_FLAGS.toLong()))
                  } else {
                      @Suppress("DEPRECATION")
                      pm.getPackageInfo(pkg, PKG_FLAGS)
                  }
                  val isExt = info.reqFeatures?.any { it.name == EXT_FEATURE } == true
                  if (isExt) extEventSink?.success(mapOf(
                      "event"     to event,
                      "pkg"       to pkg,
                      "sourceDir" to (info.applicationInfo?.sourceDir ?: "")
                  ))
              } catch (_: Exception) {}
          }
      }

      // ── Shizuku permission callback ───────────────────────────────────────
      private var pendingShizukuResult: MethodChannel.Result? = null
      private val shizukuPermListener =
          Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
              if (requestCode == SHIZUKU_CODE) {
                  val granted = grantResult == PackageManager.PERMISSION_GRANTED
                  val r = pendingShizukuResult
                  pendingShizukuResult = null
                  runOnUiThread { r?.success(granted) }
              }
          }

      override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
          super.configureFlutterEngine(flutterEngine)
          Shizuku.addRequestPermissionResultListener(shizukuPermListener)

          // ── 1. Torrent server ─────────────────────────────────────────────
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.libmtorrentserver",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "start" -> try {
                      result.success(Libmtorrentserver.start(call.argument("config")))
                  } catch (e: Exception) {
                      result.error("ERROR", e.message, null)
                  }
                  else -> result.notImplemented()
              }
          }

          // ── 2. APK installer (legacy — opens install dialog) ──────────────
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.apk_install",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "installApk" -> { installApkIntent(call.argument("filePath")); result.success(null) }
                  else         -> result.notImplemented()
              }
          }

          // ── 3. Extension loader ───────────────────────────────────────────
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.ext_loader",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "getInstalledExtensions" -> try {
                      val pm = packageManager
                      val allPkgs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                          pm.getInstalledPackages(android.content.pm.PackageManager.PackageInfoFlags.of(PKG_FLAGS.toLong()))
                      } else {
                          @Suppress("DEPRECATION")
                          pm.getInstalledPackages(PKG_FLAGS)
                      }
                      val exts = allPkgs
                          .filter { it.reqFeatures?.any { f -> f.name == EXT_FEATURE } == true }
                          .mapNotNull { info ->
                              try { mapOf(
                                  "pkg"         to info.packageName,
                                  "versionName" to (info.versionName ?: ""),
                                  "sourceDir"   to (info.applicationInfo?.sourceDir ?: "")
                              )} catch (_: Exception) { null }
                          }
                      result.success(exts)
                  } catch (e: Exception) {
                      result.error("SCAN_ERROR", e.message, null)
                  }
                  "getPrivateExtensionsDir" -> {
                      val dir = File(filesDir, PRIVATE_EXT_DIR).also { it.mkdirs() }
                      result.success(dir.absolutePath)
                  }
                  "listPrivateExtensions" -> {
                      val files = File(filesDir, PRIVATE_EXT_DIR)
                          .listFiles()
                          ?.filter { it.isFile && it.name.endsWith(PRIVATE_EXT_EXT) }
                          ?.map { mapOf("path" to it.absolutePath, "filename" to it.name) }
                          ?: emptyList<Map<String, String>>()
                      result.success(files)
                  }
                  "installPrivateExtension" -> {
                      val srcPath = call.argument<String>("path") ?: run {
                          result.error("NO_PATH", "path required", null)
                          return@setMethodCallHandler
                      }
                      try {
                          val pm = packageManager
                          val info = pm.getPackageArchiveInfo(srcPath, PKG_FLAGS)
                          if (info == null || info.reqFeatures?.any { it.name == EXT_FEATURE } != true) {
                              result.error("NOT_EXT", "Not a Tachiyomi extension", null)
                              return@setMethodCallHandler
                          }
                          val dest = File(
                              File(filesDir, PRIVATE_EXT_DIR).also { it.mkdirs() },
                              "${info.packageName}$PRIVATE_EXT_EXT"
                          )
                          File(srcPath).copyTo(dest, overwrite = true)
                          result.success(mapOf(
                              "pkg"       to info.packageName,
                              "sourceDir" to dest.absolutePath
                          ))
                      } catch (e: Exception) {
                          result.error("INSTALL_ERROR", e.message, null)
                      }
                  }
                  "removePrivateExtension" -> {
                      val pkg = call.argument<String>("pkg") ?: run {
                          result.error("NO_PKG", "pkg required", null)
                          return@setMethodCallHandler
                      }
                      File(File(filesDir, PRIVATE_EXT_DIR), "$pkg$PRIVATE_EXT_EXT").delete()
                      result.success(null)
                  }
                  else -> result.notImplemented()
              }
          }

          // ── 4. PiP ────────────────────────────────────────────────────────
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.pip"
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "enterPiP" -> {
                      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                          try {
                              val params = PictureInPictureParams.Builder().build()
                              enterPictureInPictureMode(params)
                              result.success(true)
                          } catch (e: Exception) {
                              result.error("PIP_ERROR", e.message, null)
                          }
                      } else {
                          result.error("PIP_UNSUPPORTED", "PiP requires Android 8.0+", null)
                      }
                  }
                  else -> result.notImplemented()
              }
          }

          // ── 5. Extension watcher ──────────────────────────────────────────
          EventChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.ext_watcher"
          ).setStreamHandler(object : EventChannel.StreamHandler {
              override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                  extEventSink = events
                  val filter = IntentFilter().apply {
                      addAction(Intent.ACTION_PACKAGE_ADDED)
                      addAction(Intent.ACTION_PACKAGE_REPLACED)
                      addAction(Intent.ACTION_PACKAGE_REMOVED)
                      addDataScheme("package")
                  }
                  ContextCompat.registerReceiver(
                      applicationContext, extReceiver, filter,
                      ContextCompat.RECEIVER_NOT_EXPORTED
                  )
              }
              override fun onCancel(arguments: Any?) {
                  try { applicationContext.unregisterReceiver(extReceiver) } catch (_: Exception) {}
                  extEventSink = null
              }
          })

          // ── 6. Silent installer (Shizuku + INSTALL_PACKAGES) ─────────────
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.silent_installer",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "isShizukuAvailable"         -> result.success(shizukuPing())
                  "isShizukuPermissionGranted" -> result.success(shizukuHasPerm())
                  "hasInstallPackagesPermission" -> result.success(hasInstallPerm())
                  "requestShizukuPermission"   -> requestShizukuPerm(result)
                  "grantViaShizuku"            -> grantViaShizuku(result)
                  "installApkSilent"           -> {
                      val path = call.argument<String>("path")
                      if (path == null) result.error("NO_PATH", "path required", null)
                      else try { result.success(installApkSilent(path)) }
                           catch (e: Exception) { result.error("INSTALL_ERR", e.message, null) }
                  }
                  else -> result.notImplemented()
              }
          }
      }

      // ── Shizuku helpers ───────────────────────────────────────────────────

      private fun shizukuPing(): Boolean = try { Shizuku.pingBinder() } catch (_: Exception) { false }

      private fun shizukuHasPerm(): Boolean {
          if (!shizukuPing()) return false
          return try {
              if (Shizuku.isPreV11()) true
              else Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
          } catch (_: Exception) { false }
      }

      private fun hasInstallPerm(): Boolean =
          packageManager.checkPermission(
              "android.permission.INSTALL_PACKAGES", packageName
          ) == PackageManager.PERMISSION_GRANTED

      private fun requestShizukuPerm(result: MethodChannel.Result) {
          if (!shizukuPing()) { result.error("SHIZUKU_DOWN", "Shizuku not running", null); return }
          if (shizukuHasPerm()) { result.success(true); return }
          pendingShizukuResult = result
          try { Shizuku.requestPermission(SHIZUKU_CODE) }
          catch (e: Exception) { pendingShizukuResult = null; result.error("REQ_ERR", e.message, null) }
      }

      private fun grantViaShizuku(result: MethodChannel.Result) {
          if (!shizukuHasPerm()) { result.error("NO_SHIZUKU", "Shizuku not authorized", null); return }
          try {
              val proc = Shizuku.newProcess(
                  arrayOf("pm", "grant", packageName, "android.permission.INSTALL_PACKAGES"),
                  null, null
              )
              val exit = proc.waitFor()
              if (exit == 0) result.success(true)
              else {
                  val err = proc.errorStream.bufferedReader().readText().take(200)
                  result.error("GRANT_FAIL", "Exit $exit: $err", null)
              }
          } catch (e: Exception) { result.error("GRANT_ERR", e.message, null) }
      }

      private fun installApkSilent(apkPath: String): Boolean {
          val installer = packageManager.packageInstaller
          val params = PackageInstaller.SessionParams(
              PackageInstaller.SessionParams.MODE_FULL_INSTALL
          ).also { p ->
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                  p.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
              }
          }
          val sessionId = installer.createSession(params)
          installer.openSession(sessionId).use { session ->
              val apkFile = File(apkPath)
              apkFile.inputStream().use { input ->
                  session.openWrite("package", 0, apkFile.length()).use { out ->
                      input.copyTo(out)
                      session.fsync(out)
                  }
              }
              val intent = Intent("com.watchtower.app.SILENT_INSTALL_DONE")
              val pi = PendingIntent.getBroadcast(
                  applicationContext, sessionId, intent,
                  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                      PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                  else
                      PendingIntent.FLAG_UPDATE_CURRENT
              )
              session.commit(pi.intentSender)
          }
          return true
      }

      // ── Legacy APK install (opens dialog) ────────────────────────────────
      private fun installApkIntent(filePath: String?) {
          if (filePath == null) return
          val file   = File(filePath)
          val intent = Intent(Intent.ACTION_VIEW).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
          val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
              intent.flags = intent.flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
              FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
          } else {
              Uri.fromFile(file)
          }
          intent.setDataAndType(uri, "application/vnd.android.package-archive")
          startActivity(intent)
      }

      override fun onDestroy() {
          try { Shizuku.removeRequestPermissionResultListener(shizukuPermListener) } catch (_: Exception) {}
          super.onDestroy()
      }
  }
  