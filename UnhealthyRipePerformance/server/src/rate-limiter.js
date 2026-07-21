'use strict';
// Token-bucket rate limiter — one bucket per API key (or IP as fallback).
// Default: 60 requests per 60 seconds per key.

const WINDOW_MS  = parseInt(process.env.RATE_WINDOW_MS  || '60000', 10);
const MAX_TOKENS = parseInt(process.env.RATE_MAX_TOKENS  || '60',    10);

class TokenBucket {
  constructor() {
    this.tokens   = MAX_TOKENS;
    this.lastFill = Date.now();
  }
  consume() {
    const now   = Date.now();
    const delta = now - this.lastFill;
    // Refill proportionally over the window
    const refill = (delta / WINDOW_MS) * MAX_TOKENS;
    this.tokens  = Math.min(MAX_TOKENS, this.tokens + refill);
    this.lastFill = now;
    if (this.tokens < 1) return false;
    this.tokens--;
    return true;
  }
}

const _buckets = new Map();

// Periodic cleanup — remove stale buckets every 5 min
setInterval(() => {
  const cutoff = Date.now() - WINDOW_MS * 2;
  for (const [k, v] of _buckets) {
    if (v.lastFill < cutoff) _buckets.delete(k);
  }
}, 300_000).unref();

function rateLimiterMiddleware(req, res, next) {
  const key = req.headers['x-api-key'] ||
              (req.headers['authorization'] || '').replace(/^Bearer\s+/i, '') ||
              req.ip;
  if (!key) return next(); // no key → handled by auth middleware

  let bucket = _buckets.get(key);
  if (!bucket) { bucket = new TokenBucket(); _buckets.set(key, bucket); }

  if (!bucket.consume()) {
    return res.status(429).json({
      error: 'Rate limit exceeded',
      retryAfterMs: WINDOW_MS,
    });
  }
  next();
}

module.exports = { rateLimiterMiddleware };
