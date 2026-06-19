pub mod api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

/// On Android the JVM calls JNI_OnLoad immediately after dlopen / System.loadLibrary.
/// This is the earliest safe point to perform any one-time native initialization
/// (logging, crypto back-ends, etc.) before any Dart code runs.
///
/// Nothing here is strictly required after switching reqwest to
/// `rustls-tls-webpki-roots` (which bundles Mozilla roots and needs no Android
/// initialization), but the hook is left in place as the canonical location for
/// future per-platform setup.
#[cfg(target_os = "android")]
#[allow(non_snake_case)]
#[no_mangle]
pub unsafe extern "C" fn JNI_OnLoad(
    _vm: *mut std::ffi::c_void,
    _reserved: *mut std::ffi::c_void,
) -> i32 {
    // 0x00010006 == JNI_VERSION_1_6
    // Must be returned so the JVM accepts the library.
    0x00010006
}
