package eu.kanade.tachiyomi.network

import android.content.Context
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * Minimal NetworkHelper provided by Watchtower's parent ClassLoader so that
 * Mihon/Aniyomi extension APKs loaded via DexClassLoader can resolve
 * eu.kanade.tachiyomi.network.NetworkHelper without the full Mihon framework.
 *
 * DexClassLoader checks its parent (the host app's ClassLoader) for classes not
 * found in the APK's DEX. By shipping this class at the exact package path that
 * extensions import, we provide a working OkHttpClient with no external bridge.
 */
class NetworkHelper(context: Context) {

    private val cookieJar = InMemoryCookieJar()

    /** Standard OkHttpClient used by most HttpSource extensions. */
    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .cookieJar(cookieJar)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    /**
     * Some extensions use cloudflareClient for CF-protected sites.
     * We return the same client; actual CF bypass would need an interceptor.
     */
    val cloudflareClient: OkHttpClient = client

    /** Used by download-manager style extensions. */
    val downloadClient: OkHttpClient = client
}

/**
 * Thread-safe in-memory cookie store.
 * Persists for the lifetime of the process — good enough for browse sessions.
 */
internal class InMemoryCookieJar : CookieJar {

    private val store = ConcurrentHashMap<String, MutableList<Cookie>>()

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        val key = hostKey(url)
        val existing = store.getOrPut(key) { mutableListOf() }
        val now = System.currentTimeMillis()
        synchronized(existing) {
            existing.removeAll { c ->
                c.expiresAt < now || cookies.any { it.name == c.name && it.path == c.path }
            }
            existing.addAll(cookies)
        }
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val key = hostKey(url)
        val list = store[key] ?: return emptyList()
        val now = System.currentTimeMillis()
        synchronized(list) {
            list.removeAll { it.expiresAt < now }
            return list.filter { it.matches(url) }
        }
    }

    private fun hostKey(url: HttpUrl) = "${url.scheme}://${url.host}"
}
