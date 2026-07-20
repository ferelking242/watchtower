//! Stub `aws-lc-rs` backed by ring.
//!
//! aws-lc-rs was designed as a drop-in replacement for ring (same public API).
//! This stub re-exports ring's implementations under the aws-lc-rs path so that
//! any transitive consumer (quinn-proto, rustls with aws_lc_rs feature unified
//! in) compiles and links with ZERO C code / ZERO BoringSSL in the binary.
//!
//! WHY THIS EXISTS
//! ───────────────
//! aws-lc-sys (the C layer) compiles BoringSSL which runs CRYPTO_library_init()
//! via dispatch_once on iOS. On Dopamine-jailbroken iOS 15 (TrollStore) that
//! self-test calls abort() → EXC_CRASH SIGABRT before any Flutter frame.
//!
//! RUNTIME SAFETY
//! ──────────────
//! ring is installed as the process-default TLS provider in client.rs BEFORE
//! any TLS handshake:
//!   rustls::crypto::ring::default_provider().install_default()
//! All real crypto goes through ring. The aws-lc-rs code paths compiled into
//! quinn-proto/rustls are dead code and are never reached at runtime.
//! This stub makes those dead-code paths compile and link without any C init.

pub use ring::aead;
pub use ring::agreement;
pub use ring::digest;
pub use ring::error;
pub use ring::hkdf;
pub use ring::hmac;
pub use ring::pbkdf2;
pub use ring::pkcs8;
pub use ring::rand;
pub use ring::signature;
