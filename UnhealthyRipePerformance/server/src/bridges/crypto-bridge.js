'use strict';
const crypto = require('crypto');

// ── AES-CBC CryptoJS-compatible (OpenSSL EVP_BytesToKey MD5 KDF) ────────────

function evpBytesToKey(password, salt, keyLen, ivLen) {
  const pwBuf = Buffer.isBuffer(password) ? password : Buffer.from(password, 'utf8');
  let derived = Buffer.alloc(0);
  let hash = Buffer.alloc(0);
  while (derived.length < keyLen + ivLen) {
    hash = crypto.createHash('md5').update(hash).update(pwBuf).update(salt).digest();
    derived = Buffer.concat([derived, hash]);
  }
  return { key: derived.slice(0, keyLen), iv: derived.slice(keyLen, keyLen + ivLen) };
}

function decryptAESCryptoJS(encrypted, passphrase) {
  try {
    const ct = Buffer.from(encrypted.trim(), 'base64');
    const salt = ct.slice(8, 16);
    const ciphertext = ct.slice(16);
    const { key, iv } = evpBytesToKey(passphrase, salt, 32, 16);
    const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
    return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8');
  } catch (e) {
    return encrypted;
  }
}

function encryptAESCryptoJS(plainText, passphrase) {
  try {
    const salt = crypto.randomBytes(8);
    const { key, iv } = evpBytesToKey(passphrase, salt, 32, 16);
    const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
    const encrypted = Buffer.concat([cipher.update(plainText, 'utf8'), cipher.final()]);
    return Buffer.concat([Buffer.from('Salted__'), salt, encrypted]).toString('base64');
  } catch (e) {
    return plainText;
  }
}

// ── Direct AES-CBC (key + IV from UTF-8 strings) — mirrors Dart _encrypt() ──
// Dart's encrypt package Key.fromUtf8 pads with zeros to the next valid AES key
// size (16, 24, 32). IV.fromUtf8 pads to 16.

function _toAesKey(str) {
  const buf = Buffer.from(str, 'utf8');
  if (buf.length <= 16) { const k = Buffer.alloc(16); buf.copy(k); return k; }
  if (buf.length <= 24) { const k = Buffer.alloc(24); buf.copy(k); return k; }
  const k = Buffer.alloc(32); buf.copy(k, 0, 0, 32); return k;
}

function _toAesIv(str) {
  const buf = Buffer.from(str, 'utf8');
  const iv = Buffer.alloc(16);
  buf.copy(iv, 0, 0, 16);
  return iv;
}

function cryptoHandler(text, iv, secretKeyString, shouldEncrypt) {
  try {
    const key = _toAesKey(secretKeyString);
    const ivBuf = _toAesIv(iv);
    const algo = key.length === 16 ? 'aes-128-cbc' : key.length === 24 ? 'aes-192-cbc' : 'aes-256-cbc';
    if (shouldEncrypt) {
      const cipher = crypto.createCipheriv(algo, key, ivBuf);
      return Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]).toString('base64');
    } else {
      const decipher = crypto.createDecipheriv(algo, key, ivBuf);
      return Buffer.concat([decipher.update(Buffer.from(text, 'base64')), decipher.final()]).toString('utf8');
    }
  } catch (e) {
    return text;
  }
}

// ── JS deobfuscator (port of Dart Deobfuscator) ──────────────────────────────

function deobfuscateJsPassword(inputString) {
  function getMatchingBracket(openIdx, s) {
    const open = s[openIdx];
    const close = open === '[' ? ']' : ')';
    let depth = 0;
    for (let i = openIdx; i < s.length; i++) {
      if (s[i] === open) depth++;
      else if (s[i] === close) { depth--; if (depth === 0) return i; }
    }
    return s.length - 1;
  }

  function calculateDigit(segment) {
    // segment is the content between [ and ]
    let result = 0;
    for (const ch of segment) {
      if (ch === '+') continue;
      if (ch === '!') result += 1;
      else if (ch === '[' || ch === ']' || ch === '(' || ch === ')') continue;
      else result += parseInt(ch, 10) || 0;
    }
    // simplified: count '!' occurrences
    result = (segment.match(/!/g) || []).length;
    return result;
  }

  let idx = 0;
  const brackets = ['[', '('];
  let out = '';
  while (idx < inputString.length) {
    const ch = inputString[idx];
    if (!brackets.includes(ch)) { idx++; continue; }
    const closeIdx = getMatchingBracket(idx, inputString);
    if (ch === '[') {
      out += calculateDigit(inputString.substring(idx + 1, closeIdx));
    } else {
      out += '.';
      if (closeIdx + 1 < inputString.length && inputString[closeIdx + 1] === '[') {
        const skip = getMatchingBracket(closeIdx + 1, inputString);
        idx = skip + 1;
        continue;
      }
    }
    idx = closeIdx + 1;
  }
  return out;
}

// ── JS P,A,C,K,E,R unpacker ──────────────────────────────────────────────────

function unpackJs(code) {
  const packedRe = /eval\(function\(p,a,c,k,e,[rd]?/i;
  const extractRe = /\}[(\s]*'([^']*)',\s*(\d+),\s*(\d+),\s*'([^']*)'.split\(\s*'\|'\s*\)/;
  if (!packedRe.test(code)) return null;
  const m = extractRe.exec(code);
  if (!m) return null;
  const payload = m[1], radix = parseInt(m[2], 10), count = parseInt(m[3], 10);
  const symtab = m[4].split('|');
  if (symtab.length !== count) return null;
  function unbase(str) {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    let result = 0;
    for (const ch of str) {
      result = result * radix + chars.indexOf(ch);
    }
    return result;
  }
  return payload.replace(/\b\w+\b/g, w => {
    const n = unbase(w);
    return (n < symtab.length && symtab[n]) ? symtab[n] : w;
  });
}

function unpackJsAndCombine(code) {
  const results = [];
  // Find all packed blocks and unpack them
  const packedRe = /eval\(function\(p,a,c,k,e,[rd]?/gi;
  let m;
  while ((m = packedRe.exec(code)) !== null) {
    const block = code.slice(m.index);
    const u = unpackJs(block);
    if (u) results.push(u);
  }
  if (results.length === 0) {
    const single = unpackJs(code);
    if (single) return single;
    return '';
  }
  return results.join(' ');
}

module.exports = {
  cryptoHandler,
  encryptAESCryptoJS,
  decryptAESCryptoJS,
  deobfuscateJsPassword,
  unpackJs,
  unpackJsAndCombine,
};
