pub mod api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

/// On Android the JVM calls JNI_OnLoad immediately after dlopen / System.loadLibrary.
///
/// Our JNI_OnLoad would otherwise shadow the one from rustls-platform-verifier-android,
/// preventing its initialization and causing every HTTPS request (images, APIs) to
/// panic with "Expect rustls-platform-verifier to be initialized".
///
/// We fix this by explicitly calling rustls_platform_verifier::android::init_hosted()
/// with the current JNI environment and the application context obtained via
/// ActivityThread.currentApplication().  If initialization fails for any reason we
/// log silently and continue — the app will still start, though HTTPS may not work.
#[cfg(target_os = "android")]
#[allow(non_snake_case)]
#[no_mangle]
pub unsafe extern "C" fn JNI_OnLoad(
    vm: *mut std::ffi::c_void,
    _reserved: *mut std::ffi::c_void,
) -> i32 {
    if let Ok(java_vm) = jni::JavaVM::from_raw(vm as *mut jni::sys::JavaVM) {
        // JNI_OnLoad is called from an already-attached Java thread, so get_env is safe.
        if let Ok(mut env) = java_vm.get_env() {
            let _ = init_rustls_platform_verifier(&mut env);
        }
    }
    0x00010006 // JNI_VERSION_1_6
}

/// Initialize rustls-platform-verifier using the Android application context.
///
/// Obtains the context via ActivityThread.currentApplication() — a reliable way
/// to retrieve it from native code after the app process has started.
#[cfg(target_os = "android")]
fn init_rustls_platform_verifier<'local>(
    env: &mut jni::JNIEnv<'local>,
) -> jni::errors::Result<()> {
    let at_class = env.find_class("android/app/ActivityThread")?;
    let app_val = env.call_static_method(
        at_class,
        "currentApplication",
        "()Landroid/app/Application;",
        &[],
    )?;
    let context = app_val.l()?;
    rustls_platform_verifier::android::init_hosted(env, context)
}
