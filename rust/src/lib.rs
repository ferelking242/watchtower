pub mod api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

/// On Android the JVM calls JNI_OnLoad immediately after dlopen / System.loadLibrary.
/// We use this hook to initialize rustls-platform-verifier so that the Rust TLS
/// stack (reqwest + rustls) can verify HTTPS certificates using the Android
/// system trust store.
///
/// Without this call our JNI_OnLoad would shadow the one provided by the
/// rustls-platform-verifier-android crate, preventing its initialization and
/// causing every HTTPS request to panic with:
///   "Expect rustls-platform-verifier to be initialized"
#[cfg(target_os = "android")]
#[allow(non_snake_case)]
#[no_mangle]
pub unsafe extern "C" fn JNI_OnLoad(
    vm: *mut std::ffi::c_void,
    _reserved: *mut std::ffi::c_void,
) -> i32 {
    let java_vm = jni::JavaVM::from_raw(vm as *mut jni::sys::JavaVM)
        .expect("JNI_OnLoad: invalid JavaVM pointer");
    rustls_platform_verifier::android::init_hosted(&java_vm);
    // 0x00010006 == JNI_VERSION_1_6
    0x00010006
}
