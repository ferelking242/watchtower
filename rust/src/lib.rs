pub mod api;
  mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

  /// On Android, `flutter_rust_bridge` loads our library via `System.loadLibrary()`
  /// which is called from Dart's `RustLib.init()`.  By the time that call happens,
  /// Flutter has already initialised `ndk-context` (setting the JVM and Application
  /// context).  We hook `JNI_OnLoad` to initialise `rustls-platform-verifier` using
  /// that already-available context so that every subsequent reqwest/rustls HTTPS
  /// request can verify server certificates through the Android system trust-store.
  ///
  /// Without this, rustls panics with
  /// "Expect rustls-platform-verifier to be initialized" on every HTTPS call
  /// (images, API, extension fetches, etc.).
  #[cfg(target_os = "android")]
  #[allow(non_snake_case)]
  #[no_mangle]
  pub unsafe extern "C" fn JNI_OnLoad(
      vm: *mut std::ffi::c_void,
      _reserved: *mut std::ffi::c_void,
  ) -> i32 {
      if let Ok(java_vm) = jni::JavaVM::from_raw(vm as *mut jni::sys::JavaVM) {
          // JNI_OnLoad is always called from an already-attached thread.
          if let Ok(mut env) = java_vm.get_env() {
              // Flutter sets up ndk-context before Dart calls RustLib.init(),
              // which triggers System.loadLibrary() and therefore this JNI_OnLoad.
              // The context pointer is guaranteed non-null at this point.
              let android_ctx = ndk_context::android_context();
              let raw_ctx = android_ctx.context();
              if !raw_ctx.is_null() {
                  let context = jni::objects::JObject::from_raw(raw_ctx.cast());
                  let _ = rustls_platform_verifier::android::init_hosted(&mut env, context);
              }
          }
      }
      0x00010006 // JNI_VERSION_1_6
  }
  