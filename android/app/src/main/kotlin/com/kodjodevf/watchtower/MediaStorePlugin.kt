package com.kodjodevf.watchtower

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
        when (call.method) {
            "queryVideos" -> {
                try {
                    result.success(queryVideos())
                } catch (e: Exception) {
                    result.error("QUERY_VIDEOS_FAILED", e.message, null)
                }
            }
            "queryImages" -> {
                try {
                    result.success(queryImages())
                } catch (e: Exception) {
                    result.error("QUERY_IMAGES_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
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

        // Observer les deux collections (vidéo + images)
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
    }

    private fun stopObserving() {
        contentObserver?.let {
            context.contentResolver.unregisterContentObserver(it)
        }
        contentObserver = null
    }
}
