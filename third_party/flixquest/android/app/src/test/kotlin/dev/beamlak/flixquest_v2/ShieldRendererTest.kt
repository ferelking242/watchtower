package dev.beamlak.flixquest_v2

import android.app.Application
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterJNI
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import org.robolectric.shadows.ShadowBuild
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter
import java.util.concurrent.Executors

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
@LooperMode(LooperMode.Mode.PAUSED)
class ShieldRendererTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val executor = Executors.newCachedThreadPool()

    @After fun tearDown() {
        executor.shutdownNow()
        FlutterInjector.reset()
    }

    @Test fun onlyNvidiaShieldTelevisionsMatch() {
        for (model in listOf("SHIELD Android TV", "SHIELD TV", "SHIELD TV Pro", "shield")) {
            assertTrue(model, needsShieldRendererWorkaround("NVIDIA", model, true))
        }
        assertTrue(needsShieldRendererWorkaround("nvidia", "SHIELD Android TV", true))
        assertFalse(needsShieldRendererWorkaround("NVIDIA", "SHIELD Tablet", false))
        assertFalse(needsShieldRendererWorkaround("NVIDIA", "Tegra reference device", true))
        assertFalse(needsShieldRendererWorkaround("Google", "Google TV Streamer", true))
        assertFalse(needsShieldRendererWorkaround("Amazon", "AFTMM", true))
        assertFalse(needsShieldRendererWorkaround("Sony", "BRAVIA", true))
        assertFalse(needsShieldRendererWorkaround("Samsung", "SHIELD", true))
        assertFalse(needsShieldRendererWorkaround("", "", false))
    }

    @Test fun shieldInstallsLoaderDuringAttachmentWithoutStartingFlutter() {
        ShadowBuild.setManufacturer("NVIDIA")
        ShadowBuild.setModel("SHIELD Android TV")
        shadowOf(context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager)
            .setCurrentModeType(Configuration.UI_MODE_TYPE_TELEVISION)

        attachApplication()
        val injector = FlutterInjector.instance()
        try {
            assertTrue(injector.flutterLoader() is ShieldFlutterLoader)
            assertFalse(injector.flutterLoader().initialized())
        } finally {
            injector.executorService().shutdownNow()
        }
    }

    @Test fun otherDevicesKeepExistingInjectorAndRendererDefaults() {
        ShadowBuild.setManufacturer("Google")
        ShadowBuild.setModel("Google TV Streamer")
        shadowOf(context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager)
            .setCurrentModeType(Configuration.UI_MODE_TYPE_TELEVISION)
        val original = FlutterInjector.Builder().setExecutorService(executor).build()
        FlutterInjector.setInstance(original)

        attachApplication()

        assertSame(original, FlutterInjector.instance())
        assertFalse(original.flutterLoader() is ShieldFlutterLoader)
    }

    @Test fun foregroundInitializationSelectsSkiaAndPreservesOtherArguments() {
        val jni = RecordingFlutterJNI()
        val loader = ShieldFlutterLoader(jni, executor)
        loader.startInitialization(context)
        loader.ensureInitializationComplete(
            context, arrayOf("--trace-startup", "--enable-impeller=true", "--enable-impeller"),
        )

        assertEquals(listOf("--enable-impeller=false"), jni.args.filter { it.startsWith("--enable-impeller") })
        assertTrue(jni.args.contains("--trace-startup"))
        loader.ensureInitializationComplete(context, null)
        assertEquals(1, jni.initCount)
    }

    @Test fun backgroundAsyncInitializationAlsoSelectsSkiaWithNoActivityArguments() {
        val jni = RecordingFlutterJNI()
        val loader = ShieldFlutterLoader(jni, executor)
        loader.startInitialization(context)
        var callbackCalled = false
        loader.ensureInitializationCompleteAsync(context, null, Handler(Looper.getMainLooper())) {
            callbackCalled = true
        }

        val deadline = System.nanoTime() + 5_000_000_000L
        while (!callbackCalled && System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(10)
        }
        assertTrue("Background initialization callback", callbackCalled)
        assertEquals(listOf("--enable-impeller=false"), jni.args.filter { it.startsWith("--enable-impeller") })
        assertEquals(1, jni.initCount)
    }

    private fun attachApplication() {
        // Android calls Application.attach before providers or Application.onCreate.
        ReflectionHelpers.callInstanceMethod<Void>(
            FlixQuestApplication(), "attach", ClassParameter.from(Context::class.java, context),
        )
    }

    // Exercise the real FlutterLoader up to its JNI boundary, without loading libflutter.so.
    private class RecordingFlutterJNI : FlutterJNI() {
        var args = emptyList<String>()
        var initCount = 0
        override fun loadLibrary(context: Context) {}
        override fun updateRefreshRate() {}
        override fun prefetchDefaultFontManager() {}
        override fun init(
            context: Context, args: Array<String>, bundlePath: String?,
            appStoragePath: String, engineCachesPath: String, initTimeMillis: Long, apiLevel: Int,
        ) {
            this.args = args.toList()
            initCount++
        }
    }
}
