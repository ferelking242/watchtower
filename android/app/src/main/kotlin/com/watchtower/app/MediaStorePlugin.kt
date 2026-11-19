package com.watchtower.app

import android.content.ContentUris
import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MediaStorePlugin — pont natif Android pour le Local Indexer de Watchtower.
 *
 * Expose deux canaux Flutter :
 *  - MethodChannel "watchtower/media_store"    : requêtes ponctuelles
 *  - EventChannel  "watchtower/media_store_events" : changements en temps réel
 *
 * Méthodes MethodChannel :
 *  - queryVideos  → List<Map> : tous les fichiers vidéo indexés par MediaStore
 *  - queryImages  → List<Map> : tous les fichiers image indexés par MediaStore
 *  - queryAudio   → List<Map> : tous les fichiers audio indexés par MediaStore
 *
 * EventChannel events : Map { type: "inserted"|"updated"|"deleted", path: String? }
 */
class MediaStorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    private var eventSink: EventChannel.EventSink? = null
    private var contentObserver: ContentObserver? = null

    // ── FlutterPlugin lifecycle ──────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(
            binding.binaryMessenger,
            "watchtower/media_store"
        )
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(
            binding.binaryMessenger,
            "watchtower/media_store_events"
        )
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                startObserving()
            }

            override fun onCancel(arguments: Any?) {
                stopObserving()
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        stopObserving()
    }

    // ── MethodCall handler ───────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // MediaStore queries walk tens of thousands of rows; running them on
        // the platform thread freezes the UI (and can trigger an ANR) for
        // seconds. VLC/PlayIt read MediaStore off the main thread, which is
        // why they list a full library almost instantly.
        when (call.method) {
            // "All files access" (MANAGE_EXTERNAL_STORAGE) is what lets a media
            // player walk the whole device — including folders Android's media
            // scanner ignores (.nomedia, exotic extensions, sidecar files).
            // Without it the app can only read MediaStore rows, so the Dart
            // side must know which mode it is in before deciding whether a
            // filesystem walk is worth starting.
            "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
            "storageVolumes" -> result.success(storageVolumes())
            "queryVideos", "queryImages", "queryAudio" -> {
                Thread {
                    try {
                        val rows = when (call.method) {
                            "queryVideos" -> queryVideos()
                            "queryImages" -> queryImages()
                            else -> queryAudio()
                        }
                        Handler(Looper.getMainLooper()).post { result.success(rows) }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error(
                                "${call.method}_FAILED",
                                e.message,
                                null
                            )
                        }
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    // ── Accès stockage ───────────────────────────────────────────────────────

    /// True when the app may read the whole shared storage, i.e. it can behave
    /// like a media player that walks the device instead of only listing what
    /// Android's media scanner indexed.
    private fun hasAllFilesAccess(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return android.os.Environment.isExternalStorageManager()
        }
        // Below Android 11 READ_EXTERNAL_STORAGE already covers the volume.
        return context.checkSelfPermission(
            android.Manifest.permission.READ_EXTERNAL_STORAGE
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    /// Mount points of every external volume: internal shared storage, SD card
    /// and USB OTG. A library kept on a card must be found like any other.
    @Suppress("DEPRECATION")
    private fun storageVolumes(): List<String> {
        val volumes = mutableListOf<String>()

        val manager = context.getSystemService(Context.STORAGE_SERVICE)
            as? android.os.storage.StorageManager
        val storageVolumes = manager?.storageVolumes
        if (storageVolumes != null) {
            for (volume in storageVolumes) {
                val path = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    volume.directory?.absolutePath
                } else {
                    volume.path
                }
                if (!path.isNullOrEmpty() && !volumes.contains(path)) {
                    volumes.add(path)
                }
            }
        }

        val shared = android.os.Environment.getExternalStorageDirectory()?.absolutePath
        if (!shared.isNullOrEmpty() && !volumes.contains(shared)) {
            volumes.add(shared)
        }

        return volumes
    }

    // ── Requêtes MediaStore ──────────────────────────────────────────────────

    private fun queryVideos(): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_MODIFIED,
            MediaStore.Video.Media.MIME_TYPE,
            MediaStore.Video.Media.DURATION,
        )

        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            "${MediaStore.Video.Media.DATE_MODIFIED} DESC"
        )?.use { cursor ->
            val idCol      = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val nameCol    = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val dataCol    = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
            val sizeCol    = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val dateCol    = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_MODIFIED)
            val mimeCol    = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.MIME_TYPE)
            val durCol     = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)

            while (cursor.moveToNext()) {
                val id       = cursor.getLong(idCol)
                val dataPath = cursor.getString(dataCol) ?: run {
                    // Android 10+ : reconstruire depuis content URI
                    val uri = ContentUris.withAppendedId(collection, id)
                    uri.toString()
                }
                results.add(mapOf(
                    "path"        to dataPath,
                    "displayName" to cursor.getString(nameCol),
                    "size"        to cursor.getLong(sizeCol),
                    "modifiedAt"  to cursor.getLong(dateCol) * 1000L,
                    "mimeType"    to cursor.getString(mimeCol),
                    "duration"    to cursor.getLong(durCol),
                ))
            }
        }

        return results
    }

    private fun queryImages(): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATA,
            MediaStore.Images.Media.SIZE,
            MediaStore.Images.Media.DATE_MODIFIED,
            MediaStore.Images.Media.MIME_TYPE,
        )

        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            "${MediaStore.Images.Media.DATE_MODIFIED} DESC"
        )?.use { cursor ->
            val idCol   = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
            val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
            val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_MODIFIED)
            val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)

            while (cursor.moveToNext()) {
                val id       = cursor.getLong(idCol)
                val dataPath = cursor.getString(dataCol) ?: run {
                    val uri = ContentUris.withAppendedId(collection, id)
                    uri.toString()
                }
                results.add(mapOf(
                    "path"        to dataPath,
                    "displayName" to cursor.getString(nameCol),
                    "size"        to cursor.getLong(sizeCol),
                    "modifiedAt"  to cursor.getLong(dateCol) * 1000L,
                    "mimeType"    to cursor.getString(mimeCol),
                ))
            }
        }

        return results
    }

    private fun queryAudio(): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.DURATION,
        )

        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"
        )?.use { cursor ->
            val idCol   = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
            val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
            val durCol  = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)

            while (cursor.moveToNext()) {
                val id       = cursor.getLong(idCol)
                val dataPath = cursor.getString(dataCol) ?: run {
                    // Android 10+ : reconstruire depuis content URI
                    val uri = ContentUris.withAppendedId(collection, id)
                    uri.toString()
                }
                results.add(mapOf(
                    "path"        to dataPath,
                    "displayName" to cursor.getString(nameCol),
                    "size"        to cursor.getLong(sizeCol),
                    "modifiedAt"  to cursor.getLong(dateCol) * 1000L,
                    "mimeType"    to cursor.getString(mimeCol),
                    "duration"    to cursor.getLong(durCol),
                ))
            }
        }

        return results
    }

    // ── ContentObserver (changements en temps réel) ──────────────────────────

    private fun startObserving() {
        val handler = Handler(Looper.getMainLooper())
        val observer = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                val type = when {
                    uri == null -> "unknown"
                    else -> "updated" // Android ne distingue pas insert/update/delete facilement
                }
                eventSink?.success(mapOf(
                    "type" to type,
                    "path" to uri?.toString(),
                ))
            }
        }
        contentObserver = observer

        // Observer les collections (vidéo + images + audio)
        context.contentResolver.registerContentObserver(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            true,
            observer
        )
        context.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            observer
        )
        context.contentResolver.registerContentObserver(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            true,
            observer
        )
    }

    private fun stopObserving() {
        contentObserver?.let {
            context.contentResolver.unregisterContentObserver(it)
        }
        contentObserver = null
    }
}
