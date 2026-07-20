//! Stub `aws-lc-rs` that re-exports ring.
//!
//! `aws-lc-rs` was designed as a drop-in replacement for ring; both crates
//! expose the same module layout (`aead`, `agreement`, `digest`, `hmac`,
//! `hkdf`, `rand`, `signature`, `error`).  This stub re-exports ring's
//! implementations under the aws-lc-rs path so that transitive consumers
//! (quinn-proto, rustls-webpki) compile correctly without any C code.
//!
//! `ring::default_provider()` is returned from `aws_lc_rs::default_provider()`
//! so that rustls — when its aws_lc_rs feature is unified in — still gets a
//! working CryptoProvider.  In practice the ring provider is installed first
//! via `rustls::crypto::ring::default_provider().install_default()` in
//! client.rs, so this path is never reached at runtime.

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
pub use ring::test;

/// Returns the ring-backed rustls CryptoProvider.
///
/// aws-lc-rs normally returns an aws-lc-backed provider here.  We return
/// ring instead — the caller in client.rs also calls
/// `rustls::crypto::ring::default_provider().install_default()` before any
/// TLS is used, so this function is effectively dead code at runtime.
#[cfg(feature = "rustls")]
pub fn default_provider() -> rustls::crypto::CryptoProvider {
    rustls::crypto::ring::default_provider()
}
