package com.watchtower.app

import android.content.Context
import android.util.Log
import eu.kanade.tachiyomi.network.NetworkHelper
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.intrinsics.COROUTINE_SUSPENDED
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Inline Dalvik bridge — runs Mihon/Aniyomi extension APKs directly in the
 * Watchtower process via DexClassLoader + reflection.
 *
 * Replaces the need for a separate ApkBridge app:
 *
 *   Flutter ──MethodChannel──► DalvikBridge.call(json)
 *                                     │
 *                               DexClassLoader loads APK
 *                                     │
 *                        reflection + coroutines execute method
 *                                     │
 *                              JSON result returned to Flutter
 *
 * The NetworkHelper stub (eu.kanade.tachiyomi.network.NetworkHelper) is in the
 * parent ClassLoader, so extensions can resolve it without the full Mihon framework.
 */
class DalvikBridge(private val context: Context) {

    companion object {
        private const val TAG = "DalvikBridge"
    }

    // fingerprint → cached APK file
    private val apkCache = ConcurrentHashMap<String, File>()

    // Shared NetworkHelper (one per bridge instance)
    private val networkHelper by lazy { NetworkHelper(context) }

    // ── Public entry point ────────────────────────────────────────────────────

    /**
     * Execute a Mihon/Aniyomi extension method.
     * [jsonBody] has the SAME schema the external ApkBridge HTTP endpoint expects:
     * {
     *   "method":       "getPopularManga" | "getSearchManga" | "getDetailsManga" | …,
     *   "data":         "<base64-encoded APK bytes>",
     *   "page":         1,          (optional)
     *   "search":       "query",    (optional)
     *   "filterList":   […],        (optional)
     *   "mangaData":    {"url":…},  (optional)
     *   "chapterData":  {"url":…},  (optional)
     *   "episodeData":  {"url":…},  (optional)
     * }
     */
    fun call(jsonBody: String): String {
        val req = JSONObject(jsonBody)
        val method = req.getString("method")
        val b64 = req.optString("data", "")
        if (b64.isEmpty()) throw IllegalArgumentException("'data' field is empty")

        Log.d(TAG, "call method=$method")

        val apkFile = getOrWriteApk(b64)
        val entryClass = findEntryClass(apkFile)
            ?: throw Exception("Cannot find 'tachiyomi.extension.class' in APK manifest")

        val dexCache = File(context.cacheDir, "dalvik-opt").also { it.mkdirs() }
        val loader = dalvik.system.DexClassLoader(
            apkFile.absolutePath,
            dexCache.absolutePath,
            null,
            context.classLoader
        )

        val source = instantiate(loader, entryClass)
        injectDeps(source, loader)

        return runBlocking {
            when (method) {
                "getPopularManga"  -> execList(source, loader, req, "getPopularManga",  "mangas")
                "getLatestManga"   -> execList(source, loader, req, "getLatestUpdates", "mangas")
                "getSearchManga"   -> execSearch(source, loader, req, "mangas")
                "getDetailsManga"  -> execDetails(source, loader, req)
                "getChapterList"   -> execChapterList(source, loader, req)
                "getPageList"      -> execPageList(source, loader, req)
                // Anime variants
                "getPopularAnime"  -> execList(source, loader, req, "getPopularManga",  "animes")
                "getLatestAnime"   -> execList(source, loader, req, "getLatestUpdates", "animes")
                "getSearchAnime"   -> execSearch(source, loader, req, "animes")
                "getDetailsAnime"  -> execDetails(source, loader, req)
                "getEpisodeList"   -> execChapterList(source, loader, req)
                "getVideoList"     -> execVideoList(source, loader, req)
                else               -> throw Exception("Unknown method: $method")
            }
        }
    }

    // ── APK cache ─────────────────────────────────────────────────────────────

    private fun getOrWriteApk(b64: String): File {
        val fp = (b64.take(128) + b64.length).hashCode().toString(16)
        apkCache[fp]?.takeIf { it.exists() }?.let { return it }

        val bytes = android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
        val dir = File(context.cacheDir, "dalvik-apk").also { it.mkdirs() }
        val file = File(dir, "$fp.apk")
        file.writeBytes(bytes)
        apkCache[fp] = file
        Log.d(TAG, "APK cached: $fp (${bytes.size} bytes)")
        return file
    }

    // ── Entry-class discovery ─────────────────────────────────────────────────

    private fun findEntryClass(apk: File): String? = try {
        @Suppress("DEPRECATION")
        context.packageManager
            .getPackageArchiveInfo(apk.absolutePath, android.content.pm.PackageManager.GET_META_DATA)
            ?.applicationInfo?.metaData?.run {
                getString("tachiyomi.extension.class")
                    ?: getString("aniyomi.extension.class")
                    ?: getString("extension.class")
            }
    } catch (e: Exception) {
        Log.w(TAG, "findEntryClass: ${e.message}")
        null
    }

    // ── Instantiation ─────────────────────────────────────────────────────────

    private fun instantiate(loader: ClassLoader, className: String): Any {
        val cls = loader.loadClass(className)
        return try {
            cls.getDeclaredConstructor().newInstance()
        } catch (_: NoSuchMethodException) {
            cls.getDeclaredConstructor(Context::class.java).newInstance(context)
        }
    }

    // ── Dependency injection ──────────────────────────────────────────────────
    //
    // Walk the class hierarchy and inject NetworkHelper / OkHttpClient into
    // null fields that match by name or type.

    private fun injectDeps(source: Any, loader: ClassLoader) {
        try {
            var cls: Class<*>? = source.javaClass
            while (cls != null && cls.name != "java.lang.Object") {
                for (f in cls.declaredFields) {
                    f.isAccessible = true
                    if (f.get(source) != null) continue
                    val typeName = f.type.name
                    when {
                        typeName.contains("NetworkHelper") -> {
                            f.set(source, networkHelper)
                            Log.d(TAG, "Injected NetworkHelper into ${f.name}")
                        }
                        typeName == "okhttp3.OkHttpClient" -> {
                            f.set(source, networkHelper.client)
                            Log.d(TAG, "Injected OkHttpClient into ${f.name}")
                        }
                    }
                }
                cls = cls.superclass
            }
        } catch (e: Exception) {
            Log.w(TAG, "injectDeps: ${e.message}")
        }
    }

    // ── Suspend-function caller ───────────────────────────────────────────────

    @Suppress("UNCHECKED_CAST")
    private suspend fun <T> callSuspend(obj: Any, name: String, vararg args: Any?): T {
        val method = generateSequence<Class<*>>(obj.javaClass) { it.superclass }
            .flatMap { it.declaredMethods.asSequence() }
            .firstOrNull { m ->
                m.name == name &&
                m.parameterCount == args.size + 1 &&
                m.parameterTypes.last().name.contains("Continuation")
            }
            ?: throw NoSuchMethodException("suspend fun $name(${args.size} params) not found on ${obj.javaClass.name}")

        method.isAccessible = true

        return suspendCancellableCoroutine { cont ->
            try {
                val result = method.invoke(obj, *args, cont)
                if (result !== COROUTINE_SUSPENDED) {
                    cont.resume(result as T) {}
                }
            } catch (e: java.lang.reflect.InvocationTargetException) {
                cont.resumeWithException(e.cause ?: e)
            } catch (e: Exception) {
                cont.resumeWithException(e)
            }
        }
    }

    // ── Model factories ───────────────────────────────────────────────────────

    private fun newSManga(loader: ClassLoader, url: String): Any {
        val cls = loader.loadClass("eu.kanade.tachiyomi.source.model.SManga")
        val instance = try {
            // Kotlin companion factory: SManga.create()
            val comp = cls.getDeclaredField("Companion").also { it.isAccessible = true }.get(null)
            comp.javaClass.getDeclaredMethod("create").also { it.isAccessible = true }.invoke(comp)
        } catch (_: Exception) {
            cls.getDeclaredConstructor().newInstance()
        }
        setField(instance, "url", url)
        return instance
    }

    private fun newSChapter(loader: ClassLoader, url: String): Any {
        val cls = loader.loadClass("eu.kanade.tachiyomi.source.model.SChapter")
        val instance = try {
            val comp = cls.getDeclaredField("Companion").also { it.isAccessible = true }.get(null)
            comp.javaClass.getDeclaredMethod("create").also { it.isAccessible = true }.invoke(comp)
        } catch (_: Exception) {
            cls.getDeclaredConstructor().newInstance()
        }
        setField(instance, "url", url)
        return instance
    }

    private fun newFilterList(loader: ClassLoader): Any =
        loader.loadClass("eu.kanade.tachiyomi.source.model.FilterList")
            .getDeclaredConstructor(List::class.java)
            .newInstance(emptyList<Any>())

    // ── Method executors ──────────────────────────────────────────────────────

    private suspend fun execList(
        source: Any, loader: ClassLoader,
        req: JSONObject, methodName: String, listKey: String
    ): String {
        val page = req.optInt("page", 1)
        val result = callSuspend<Any>(source, methodName, page)
        return serializeMangasPage(result, listKey)
    }

    private suspend fun execSearch(
        source: Any, loader: ClassLoader,
        req: JSONObject, listKey: String
    ): String {
        val page    = req.optInt("page", 1)
        val query   = req.optString("search", "")
        val filters = newFilterList(loader)
        val result  = callSuspend<Any>(source, "getSearchManga", page, query, filters)
        return serializeMangasPage(result, listKey)
    }

    private suspend fun execDetails(
        source: Any, loader: ClassLoader, req: JSONObject
    ): String {
        val url = req.optJSONObject("mangaData")?.optString("url")
            ?: req.optJSONObject("animeData")?.optString("url")
            ?: throw IllegalArgumentException("Missing url in mangaData/animeData")
        val manga  = newSManga(loader, url)
        val result = callSuspend<Any>(source, "getMangaDetails", manga)
        return serializeManga(result).toString()
    }

    private suspend fun execChapterList(
        source: Any, loader: ClassLoader, req: JSONObject
    ): String {
        val url = req.optJSONObject("mangaData")?.optString("url")
            ?: req.optJSONObject("animeData")?.optString("url")
            ?: throw IllegalArgumentException("Missing url in mangaData/animeData")
        val manga   = newSManga(loader, url)
        val results = callSuspend<List<*>>(source, "getChapterList", manga)
        return JSONArray().also { arr ->
            results.filterNotNull().forEach { arr.put(serializeChapter(it)) }
        }.toString()
    }

    private suspend fun execPageList(
        source: Any, loader: ClassLoader, req: JSONObject
    ): String {
        val url     = req.optJSONObject("chapterData")?.optString("url")
            ?: throw IllegalArgumentException("Missing url in chapterData")
        val chapter = newSChapter(loader, url)
        val results = callSuspend<List<*>>(source, "getPageList", chapter)
        return JSONArray().also { arr ->
            results.filterNotNull().forEach { arr.put(serializePage(it)) }
        }.toString()
    }

    private suspend fun execVideoList(
        source: Any, loader: ClassLoader, req: JSONObject
    ): String {
        val url     = req.optJSONObject("episodeData")?.optString("url")
            ?: throw IllegalArgumentException("Missing url in episodeData")
        val episode = newSChapter(loader, url)
        val results = callSuspend<List<*>>(source, "getVideoList", episode)
        return JSONArray().also { arr ->
            results.filterNotNull().forEach { v ->
                arr.put(JSONObject().apply {
                    put("videoUrl", getField(v, "videoUrl") ?: getField(v, "url") ?: "")
                    put("quality",  getField(v, "quality") ?: "")
                    put("url",      getField(v, "url") ?: "")
                    // Headers: serialize namesAndValues if available
                    val hdrs = getField(v, "headers")
                    if (hdrs != null) {
                        try {
                            val nv = getField(hdrs, "namesAndValues") as? Array<*>
                            if (nv != null) {
                                val nvArr = JSONArray()
                                nv.forEach { nvArr.put(it?.toString() ?: "") }
                                put("headers", JSONObject().put("namesAndValues\$okhttp", nvArr))
                            }
                        } catch (_: Exception) {}
                    }
                    // Subtitles / audio tracks (if any)
                    val subs = getField(v, "subtitleTracks") as? List<*>
                    val audio = getField(v, "audioTracks") as? List<*>
                    if (subs != null) put("subtitleTracks", JSONArray(subs.map { t ->
                        JSONObject().apply {
                            put("file",  getField(t!!, "file") ?: getField(t, "url") ?: "")
                            put("label", getField(t, "label") ?: getField(t, "lang") ?: "")
                        }
                    }))
                    if (audio != null) put("audioTracks", JSONArray(audio.map { t ->
                        JSONObject().apply {
                            put("file",  getField(t!!, "file") ?: getField(t, "url") ?: "")
                            put("label", getField(t, "label") ?: getField(t, "lang") ?: "")
                        }
                    }))
                })
            }
        }.toString()
    }

    // ── Serializers ───────────────────────────────────────────────────────────

    private fun serializeMangasPage(page: Any, listKey: String): String {
        val mangas: List<*> = try {
            page.javaClass.getMethod("getMangas").invoke(page) as List<*>
        } catch (_: Exception) {
            getField(page, "mangas") as? List<*> ?: emptyList<Any>()
        }
        val hasNext: Boolean = try {
            page.javaClass.getMethod("getHasNextPage").invoke(page) as Boolean
        } catch (_: Exception) {
            getField(page, "hasNextPage") as? Boolean ?: false
        }
        val arr = JSONArray()
        mangas.filterNotNull().forEach { arr.put(serializeManga(it)) }
        return JSONObject().apply {
            put(listKey, arr)
            put("hasNextPage", hasNext)
        }.toString()
    }

    private fun serializeManga(m: Any): JSONObject {
        val genreStr = getField(m, "genre") as? String ?: ""
        val genres   = if (genreStr.isBlank()) JSONArray()
        else JSONArray(genreStr.split(", ").map { it.trim() })
        return JSONObject().apply {
            put("url",           getField(m, "url") ?: "")
            put("title",         getField(m, "title") ?: "")
            put("artist",        getField(m, "artist"))
            put("author",        getField(m, "author"))
            put("description",   getField(m, "description"))
            put("genres",        genres)
            put("status",        (getField(m, "status") as? Int) ?: 0)
            put("thumbnail_url", getField(m, "thumbnail_url"))
        }
    }

    private fun serializeChapter(c: Any) = JSONObject().apply {
        put("url",            getField(c, "url") ?: "")
        put("name",           getField(c, "name") ?: "")
        put("date_upload",    (getField(c, "date_upload") as? Long) ?: 0L)
        put("scanlator",      getField(c, "scanlator"))
        put("chapter_number", (getField(c, "chapter_number") as? Float)?.toDouble() ?: -1.0)
    }

    private fun serializePage(p: Any) = JSONObject().apply {
        put("index",    (getField(p, "index") as? Int) ?: 0)
        put("url",      getField(p, "url") ?: "")
        put("imageUrl", getField(p, "imageUrl"))
    }

    // ── Reflection helpers ────────────────────────────────────────────────────

    private fun getField(obj: Any, name: String): Any? {
        var cls: Class<*>? = obj.javaClass
        while (cls != null && cls.name != "java.lang.Object") {
            try {
                val f = cls.getDeclaredField(name)
                f.isAccessible = true
                return f.get(obj)
            } catch (_: NoSuchFieldException) {}
            cls = cls.superclass
        }
        return null
    }

    private fun setField(obj: Any, name: String, value: Any?) {
        var cls: Class<*>? = obj.javaClass
        while (cls != null && cls.name != "java.lang.Object") {
            try {
                val f = cls.getDeclaredField(name)
                f.isAccessible = true
                f.set(obj, value)
                return
            } catch (_: NoSuchFieldException) {}
            cls = cls.superclass
        }
    }
}
