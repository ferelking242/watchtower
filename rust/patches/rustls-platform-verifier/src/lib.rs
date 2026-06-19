//! Stub rustls-platform-verifier that satisfies reqwest 0.13.2's type requirements.
  //!
  //! reqwest's __rustls code path at src/async_impl/client.rs:752 and :760 references
  //! rustls_platform_verifier::Verifier. Since we call use_preconfigured_tls() before
  //! building any Client, reqwest's internal TLS setup (which uses this Verifier) is
  //! bypassed entirely. These functions are compiled but never executed.
  //!
  //! This stub removes the aws-lc-rs → aws-lc-sys → BoringSSL C code that the real
  //! rustls-platform-verifier pulls in via rustls-webpki[aws_lc_rs]. That C code was
  //! causing abort() on TrollStore-installed apps on iOS due to memory pressure during
  //! its static initialization phase.

  use std::sync::Arc;

  use rustls::{
      client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier},
      crypto::CryptoProvider,
      pki_types::{CertificateDer, ServerName, UnixTime},
      DigitallySignedStruct, Error, SignatureScheme,
  };

  /// Stub certificate verifier.
  ///
  /// Never instantiated at runtime — reqwest's use_preconfigured_tls() skips all
  /// TLS setup that references this type. The unreachable!() guards below ensure
  /// a clear panic if something does call through (a bug), rather than silent
  /// certificate bypass.
  #[derive(Debug)]
  pub struct Verifier;

  impl Verifier {
      /// Create a new stub verifier (always succeeds, never used at runtime).
      pub fn new(
          _provider: Arc<CryptoProvider>,
      ) -> Result<Self, Box<dyn std::error::Error + Send + Sync + 'static>> {
          Ok(Verifier)
      }

      /// Create a new stub verifier with extra roots (always succeeds, never used at runtime).
      pub fn new_with_extra_roots(
          _roots: impl IntoIterator<Item = CertificateDer<'static>>,
          _provider: Arc<CryptoProvider>,
      ) -> Result<Self, Box<dyn std::error::Error + Send + Sync + 'static>> {
          Ok(Verifier)
      }
  }

  impl ServerCertVerifier for Verifier {
      fn verify_server_cert(
          &self,
          _end_entity: &CertificateDer<'_>,
          _intermediates: &[CertificateDer<'_>],
          _server_name: &ServerName<'_>,
          _ocsp_response: &[u8],
          _now: UnixTime,
      ) -> Result<ServerCertVerified, Error> {
          unreachable!(
              "stub rustls-platform-verifier::Verifier::verify_server_cert called —                this should never happen because use_preconfigured_tls() is always used"
          )
      }

      fn verify_tls12_signature(
          &self,
          _message: &[u8],
          _cert: &CertificateDer<'_>,
          _dss: &DigitallySignedStruct,
      ) -> Result<HandshakeSignatureValid, Error> {
          unreachable!("stub rustls-platform-verifier: verify_tls12_signature")
      }

      fn verify_tls13_signature(
          &self,
          _message: &[u8],
          _cert: &CertificateDer<'_>,
          _dss: &DigitallySignedStruct,
      ) -> Result<HandshakeSignatureValid, Error> {
          unreachable!("stub rustls-platform-verifier: verify_tls13_signature")
      }

      fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
          unreachable!("stub rustls-platform-verifier: supported_verify_schemes")
      }
  }
  