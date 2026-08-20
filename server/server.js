'use strict';
const app = require('./src/api');

const PORT = parseInt(process.env.PORT || '8080', 10);

// ── Crash resilience: prevent silent exits on unhandled errors ───────────────
// Without these, a single unhandled promise rejection kills the process
// with zero useful output — especially common with async extension code.
process.on('uncaughtException', (err) => {
  console.error('[FATAL] uncaughtException — process staying alive:', err);
});
process.on('unhandledRejection', (reason) => {
  console.error('[FATAL] unhandledRejection — process staying alive:', reason);
});

// ── Graceful shutdown ────────────────────────────────────────────────────────
// Allow in-flight requests to finish before exiting (30s max).
function shutdown(signal) {
  console.log(`[SERVER] ${signal} received — shutting down gracefully…`);
  server.close(() => {
    console.log('[SERVER] Closed all connections.');
    process.exit(0);
  });
  // Force exit after 30s if connections don't drain
  setTimeout(() => {
    console.error('[SERVER] Forced exit after 30s timeout.');
    process.exit(1);
  }, 30000).unref();
}

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`[Watchtower Server] listening on :${PORT}`);
  console.log(`[Watchtower Server] API key: ${process.env.API_KEY || '(none — set API_KEY env var)'}`);
});

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
