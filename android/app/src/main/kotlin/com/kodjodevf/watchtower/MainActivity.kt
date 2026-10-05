package com.watchtower.app

  import android.app.DownloadManager
  import android.app.PendingIntent
  import android.app.PictureInPictureParams
  import android.content.Context
  import android.content.Intent
  import android.content.pm.PackageInstaller
  import android.content.pm.PackageManager
  import android.net.Uri
  import android.os.Build
  import android.os.Environment
  import androidx.annotation.NonNull
  import androidx.core.content.FileProvider
  import io.flutter.embedding.android.FlutterFragmentActivity
  import io.flutter.embedding.engine.FlutterEngine
  import io.flutter.plugin.common.MethodChannel
  import io.flutter.plugin.common.StandardMethodCodec
  import com.kodjodevf.watchtower.DownloadForegroundService
  import com.kodjodevf.watchtower.MediaStorePlugin
  import libmtorrentserver.Libmtorrentserver
  import rikka.shizuku.Shizuku
  import java.io.File

  class MainActivity : FlutterFragmentActivity() {

      companion object {
          private const val SHIZUKU_CODE    = 1042
      }

      // ── Shizuku permission callback ────────────────────────────────────────
      private var pendingShizukuResult: MethodChannel.Result? = null
  private var _wakeLock: android.os.PowerManager.WakeLock? = null
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
          flutterEngine.plugins.add(MediaStorePlugin()) // Local Indexer MediaStore bridge

          // ── 1. Torrent server ──────────────────────────────────────────────
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

          // ── 2. APK installer (legacy — opens install dialog) ───────────────
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

          // ── 5. PiP ─────────────────────────────────────────────────────────
          // ── Device capabilities (RAM detection) ───────────────────────────
          // Queried once at startup by DeviceCapabilities.dart to select the
          // correct image-cache tier for this device. No permissions required.
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.device_capabilities"
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "getPhysicalMemoryMB" -> {
                      val am = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                      val mi = android.app.ActivityManager.MemoryInfo()
                      am.getMemoryInfo(mi)
                      result.success((mi.totalMem / 1024 / 1024).toInt())
                  }
                  else -> result.notImplemented()
              }
          }

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

          // ── 6. Home screen shortcuts ────────────────────────────────────────
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.shortcuts"
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "isSupported" -> {
                      val supported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                          getSystemService(android.content.pm.ShortcutManager::class.java)
                              ?.isRequestPinShortcutSupported == true
                      } else false
                      result.success(supported)
                  }
                  "pinShortcut" -> {
                      val id    = call.argument<String>("id")    ?: "plugin"
                      val label = call.argument<String>("label") ?: "Plugin"
                      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                          result.error("NOT_SUPPORTED", "Android 8.0+ requis", null)
                          return@setMethodCallHandler
                      }
                      val sm = getSystemService(android.content.pm.ShortcutManager::class.java)
                      if (sm?.isRequestPinShortcutSupported != true) {
                          result.error("NOT_SUPPORTED", "Launcher incompatible", null)
                          return@setMethodCallHandler
                      }
                      try {
                          val intent = packageManager.getLaunchIntentForPackage(packageName)!!.apply {
                              action = Intent.ACTION_MAIN
                              addCategory(Intent.CATEGORY_LAUNCHER)
                              putExtra("shortcut_plugin", id)
                              flags = Intent.FLAG_ACTIVITY_NEW_TASK
                          }
                          val shortcutInfo = android.content.pm.ShortcutInfo.Builder(
                              applicationContext, "plugin_$id"
                          )
                              .setShortLabel(label.take(25))
                              .setLongLabel(label)
                              .setIcon(android.graphics.drawable.Icon.createWithResource(
                                  applicationContext, R.mipmap.launcher_icon))
                              .setIntent(intent)
                              .build()
                          sm.requestPinShortcut(shortcutInfo, null)
                          result.success(true)
                      } catch (e: Exception) {
                          result.error("PIN_ERROR", e.message, null)
                      }
                  }
                  else -> result.notImplemented()
              }
          }

          // ── 7. Binary utils ────────────────────────────────────────────────
          // All compiled ELF binaries (aria2c, ffmpeg, python) in production apps
          // (youtubedl-android, Seal, ytdlnis) live in jniLibs/ → nativeLibraryDir.
          // Files written to app data dir (app_data_file SELinux context) cannot be
          // exec'd by untrusted_app on Android 10+ per AOSP neverallow rule in
          // private/app_neverallows.te. ProcessBuilder.start() has the SAME
          // restriction — it calls fork()+execve() in the same untrusted_app domain.
          //
          // runProcess strategy:
          //   1. Shizuku (if available & granted): Shizuku.newProcess() runs in the
          //      SELinux `shell` domain which has explicit allow shell app_data_file
          //      execute_no_trans in AOSP — this is why `adb shell ./binary` works.
          //   2. ProcessBuilder fallback: works on permissive devices / pre-Android-10.
          //
          // getNativeLibraryDir: returns applicationInfo.nativeLibraryDir so Dart
          //   can find binaries packaged as libXXX.so in jniLibs/ (the canonical
          //   approach for downloaded binary updates delivered via APK releases).
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.binary_utils",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              when (call.method) {
                  "setExecutable" -> {
                      val path = call.argument<String>("path") ?: run {
                          result.error("NO_PATH", "path required", null)
                          return@setMethodCallHandler
                      }
                      val ok = java.io.File(path).setExecutable(true, false)
                      result.success(ok)
                  }
                  "getNativeLibraryDir" -> {
                      result.success(applicationInfo.nativeLibraryDir)
                  }
                  "runProcess" -> {
                      val path = call.argument<String>("path") ?: run {
                          result.error("NO_PATH", "path required", null)
                          return@setMethodCallHandler
                      }
                      val args = call.argument<List<String>>("args") ?: emptyList()
                      @Suppress("UNCHECKED_CAST")
                      val envOverrides = call.argument<Map<String, String>>("env")
                      val cmd = (listOf(path) + args).toTypedArray()
                      // Binaries live in nativeLibraryDir (always exec-capable, no SELinux
                      // restriction). Direct ProcessBuilder — no Shizuku needed.
                      try {
                          val pb = ProcessBuilder(*cmd).redirectErrorStream(true)
                          // Apply caller-supplied environment overrides (e.g. TMPDIR so
                          // staticx extracts to an exec-capable directory, not cacheDir).
                          envOverrides?.let { pb.environment().putAll(it) }
                          val proc = pb.start()
                          val output   = proc.inputStream.bufferedReader().readText()
                          val exitCode = proc.waitFor()
                          result.success(mapOf("exitCode" to exitCode, "output" to output, "via" to "processbuilder"))
                      } catch (e: Exception) {
                          result.error("EXEC_ERROR", e.message ?: "unknown", null)
                      }
                  }
                  else -> result.notImplemented()
              }
          }

          // ── 8. Silent installer (Shizuku + INSTALL_PACKAGES) ──────────────
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



        // ── 8b. Wake lock for background downloads ─────────────────────────────
        // Keeps the CPU awake (partial wakelock) during APK downloads so that
        // Android does not throttle the network stream when the app is backgrounded.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.watchtower.app.wakelock",
            StandardMethodCodec.INSTANCE,
            flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    try {
                        if (_wakeLock == null || !(_wakeLock!!.isHeld)) {
                            @Suppress("DEPRECATION")
                            _wakeLock = (getSystemService(POWER_SERVICE) as android.os.PowerManager)
                                .newWakeLock(
                                    android.os.PowerManager.PARTIAL_WAKE_LOCK,
                                    "com.watchtower.app:download"
                                )
                            _wakeLock!!.acquire(30 * 60 * 1000L) // max 30 min
                        }
                        result.success(null)
                    } catch (e: Exception) { result.error("WAKELOCK_ERR", e.message, null) }
                }
                "release" -> {
                    try {
                        if (_wakeLock?.isHeld == true) _wakeLock!!.release()
                        _wakeLock = null
                        result.success(null)
                    } catch (e: Exception) { result.error("WAKELOCK_ERR", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }

          // ── 9. Plugin executor (Flare eval bridge) ──────────────────────────
          // Python-based execution removed — plugins now use native binaries only.
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.plugin",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { _, result ->
              result.error("NOT_SUPPORTED", "Python plugin execution removed", null)
          }

          // ── 10. Plugin storage (SharedPreferences pour préférences plugin) ───
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.storage",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              val prefs = getSharedPreferences("watchtower_plugin_prefs", MODE_PRIVATE)
              when (call.method) {
                  "get" -> {
                      val key = call.argument<String>("key") ?: run {
                          result.error("NO_KEY", "key required", null)
                          return@setMethodCallHandler
                      }
                      result.success(prefs.getString(key, null))
                  }
                  "set" -> {
                      val key   = call.argument<String>("key")   ?: run { result.error("NO_KEY", "key required", null); return@setMethodCallHandler }
                      val value = call.argument<String>("value") ?: ""
                      prefs.edit().putString(key, value).apply()
                      result.success(null)
                  }
                  "delete" -> {
                      val key = call.argument<String>("key") ?: run {
                          result.error("NO_KEY", "key required", null)
                          return@setMethodCallHandler
                      }
                      prefs.edit().remove(key).apply()
                      result.success(null)
                  }
                  else -> result.notImplemented()
              }
          }

          // ── 11. System DownloadManager (background APK download) ──────────────
          // Android's DownloadManager runs in a separate system process and survives
          // the app being backgrounded or killed. This replaces the Dart http.Client
          // approach which was fragile across app lifecycle events.
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "com.watchtower.app.download_manager",
              StandardMethodCodec.INSTANCE,
              flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
          ).setMethodCallHandler { call, result ->
              val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
              when (call.method) {
                  "startDownload" -> {
                      val url      = call.argument<String>("url")      ?: run { result.error("NO_URL",  "url required",  null); return@setMethodCallHandler }
                      val fileName = call.argument<String>("fileName") ?: run { result.error("NO_FILE", "fileName required", null); return@setMethodCallHandler }
                      val title    = call.argument<String>("title")    ?: "Watchtower Update"

                      try {
                          val request = DownloadManager.Request(Uri.parse(url)).apply {
                              setTitle(title)
                              setDescription("Téléchargement de la mise à jour Watchtower")
                              setNotificationVisibility(
                                  DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                              setDestinationInExternalPublicDir(
                                  Environment.DIRECTORY_DOWNLOADS, fileName)
                              addRequestHeader("Accept-Encoding", "identity")
                              setAllowedOverMetered(true)
                              setAllowedOverRoaming(true)
                          }
                          val downloadId = dm.enqueue(request)
                          result.success(downloadId)
                      } catch (e: Exception) {
                          result.error("DL_ERROR", e.message, null)
                      }
                  }

                  "queryProgress" -> {
                      val downloadId = call.argument<Number>("downloadId")?.toLong()
                          ?: run { result.error("NO_ID", "downloadId required", null); return@setMethodCallHandler }

                      val query  = DownloadManager.Query().setFilterById(downloadId)
                      val cursor = dm.query(query)
                      if (!cursor.moveToFirst()) {
                          cursor.close()
                          result.error("NOT_FOUND", "Download $downloadId not found", null)
                          return@setMethodCallHandler
                      }

                      val received  = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                      val total     = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                      val status    = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                      val reason    = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                      val localUri  = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI)) ?: ""
                      cursor.close()

                      result.success(mapOf(
                          "received"  to received,
                          "total"     to total,
                          "status"    to status,
                          "reason"    to reason,
                          "localPath" to localUri,
                      ))
                  }

                  "cancelDownload" -> {
                      val downloadId = call.argument<Number>("downloadId")?.toLong()
                          ?: run { result.error("NO_ID", "downloadId required", null); return@setMethodCallHandler }
                      dm.remove(downloadId)
                      result.success(null)
                  }

                  else -> result.notImplemented()
              }
          }

          // ── 12. Download Foreground Service control ────────────────────────
          // Flutter calls start/stop/update to drive DownloadForegroundService.
          // This keeps the download queue alive when the app is backgrounded.
          MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "watchtower/download_service"
          ).setMethodCallHandler { call, result ->
              try {
                  val count    = call.argument<Int>("count")    ?: 0
                  val title    = call.argument<String>("title")    ?: "Téléchargement en cours…"
                  val subtitle = call.argument<String>("subtitle") ?: ""
                  val progress = call.argument<Int>("progress")    ?: -1
                  val downloadedBytes = call.argument<Number>("downloadedBytes")?.toLong() ?: 0L
                  val totalBytes = call.argument<Number>("totalBytes")?.toLong()
                  val speedMbs = call.argument<Number>("speedMbs")?.toDouble() ?: 0.0
                  val etaSeconds = call.argument<Number>("etaSeconds")?.toInt()
                  val quality = call.argument<String>("quality") ?: ""
                  when (call.method) {
                      "start"  -> {
                          DownloadForegroundService.start(
                              applicationContext, count, title, subtitle, progress,
                              downloadedBytes, totalBytes, speedMbs, etaSeconds, quality,
                          )
                          result.success(null)
                      }
                      "update" -> {
                          DownloadForegroundService.update(
                              applicationContext, count, title, subtitle, progress,
                              downloadedBytes, totalBytes, speedMbs, etaSeconds, quality,
                          )
                          result.success(null)
                      }
                      "stop"   -> { DownloadForegroundService.stop(applicationContext);                                     result.success(null) }
                      "openFile" -> { openDownloadedFile(call.argument("filePath")); result.success(null) }
                      else     -> result.notImplemented()
                  }
              } catch (e: Exception) {
                  result.error("SVC_ERR", e.message, null)
              }
          }
      }

      private fun openDownloadedFile(filePath: String?) {
          if (filePath.isNullOrBlank()) return
          val file = File(filePath)
          if (!file.exists()) return
          val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
          val intent = Intent(Intent.ACTION_VIEW).apply {
              setDataAndType(uri, contentResolver.getType(uri) ?: "video/*")
              addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
          }
          startActivity(Intent.createChooser(intent, "Lire avec…"))
      }

      private fun pluginJsonToMap(json: org.json.JSONObject): Map<String, Any?> {
          val map = mutableMapOf<String, Any?>()
          for (key in json.keys()) {
              map[key] = when (val v = json.get(key)) {
                  is org.json.JSONObject -> pluginJsonToMap(v)
                  is org.json.JSONArray  -> (0 until v.length()).map { i -> v.get(i) }
                  org.json.JSONObject.NULL -> null
                  else -> v
              }
          }
          return map
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
              val shizukuClass = Class.forName("rikka.shizuku.Shizuku")
              val newProcessMethod = shizukuClass.getMethod(
                  "newProcess",
                  Array<String>::class.java,
                  Array<String>::class.java,
                  String::class.java
              )
              @Suppress("UNCHECKED_CAST")
              val proc = newProcessMethod.invoke(
                  null,
                  arrayOf("pm", "grant", packageName, "android.permission.INSTALL_PACKAGES"),
                  null,
                  null
              ) as Process
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

      // ── Legacy APK install (opens dialog) ─────────────────────────────────
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
