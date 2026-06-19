#!/usr/bin/env python3
"""
Watchtower Telegram Source Plugin
Script Pyrogram — communication via stdout JSON / binaire raw
Logs/erreurs → stderr uniquement (stdout réservé aux données)

Commandes :
  --action auth_send_code    : Envoie OTP au téléphone → retourne phone_code_hash
  --action auth_verify_code  : Vérifie le code OTP → retourne session_string
  --action auth_check_password : Vérifie le mot de passe 2FA → retourne session_string
  --action metadata          : Metadata du canal (cover, desc, subscribers)
  --action list              : Liste des fichiers CBR/CBZ/ZIP/PDF/EPUB (sans thumbs inline)
  --action stream            : Stream binaire via temp file → stdout (pas d'OOM)
  --action search            : Recherche dans les messages du canal
  --action thumbnail         : Thumbnail base64 d'un fichier spécifique
"""

import sys
import os
import json
import signal
import asyncio
import argparse
import base64
import time
import tempfile
import logging
from io import BytesIO

logging.basicConfig(stream=sys.stderr, level=logging.WARNING,
                    format='[TG] %(levelname)s: %(message)s')
log = logging.getLogger("tgsource")

try:
    from pyrogram import Client
    from pyrogram.types import Message
    from pyrogram.errors import (
        FloodWait, UserDeactivated, AuthKeyUnregistered,
        PhoneCodeInvalid, PhoneCodeExpired, SessionPasswordNeeded,
        PhoneNumberInvalid, PhoneNumberBanned, PasswordHashInvalid,
    )
    from pyrogram.sessions import StringSession
except ImportError as e:
    print(json.dumps({"status": "error", "error": f"Pyrogram non disponible: {e}"}))
    sys.exit(1)

SUPPORTED_MIME = {
    "application/x-cbr",
    "application/x-cbz",
    "application/zip",
    "application/x-zip-compressed",
    "application/pdf",
    "application/epub+zip",
    "application/x-rar-compressed",
    "application/vnd.comicbook+zip",
    "application/vnd.comicbook-rar",
    "application/octet-stream",
}

SUPPORTED_EXT = {".cbr", ".cbz", ".zip", ".pdf", ".epub", ".rar", ".7z"}

_stream_cancelled = False


def _on_sigterm(signum, frame):
    global _stream_cancelled
    _stream_cancelled = True
    log.info("SIGTERM reçu — annulation du stream")


signal.signal(signal.SIGTERM, _on_sigterm)


def out_json(data: dict):
    sys.stdout.write(json.dumps(data, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def err_json(data: dict):
    sys.stderr.write(json.dumps(data) + "\n")
    sys.stderr.flush()


def is_supported_doc(msg: "Message") -> bool:
    if not msg.document:
        return False
    mime = (msg.document.mime_type or "").lower()
    fname = (msg.document.file_name or "").lower()
    ext = os.path.splitext(fname)[1]
    return mime in SUPPORTED_MIME or ext in SUPPORTED_EXT


def make_client(api_id: int, api_hash: str, session: str = None) -> Client:
    if session:
        return Client(
            name="watchtower_tg",
            api_id=api_id,
            api_hash=api_hash,
            session_string=session,
            in_memory=True,
        )
    return Client(
        name="watchtower_tg",
        api_id=api_id,
        api_hash=api_hash,
        in_memory=True,
    )


async def _retry(coro_fn, retries=3, base_delay=1.0):
    for attempt in range(retries):
        try:
            return await coro_fn()
        except FloodWait as fw:
            wait = fw.value + 1
            log.warning(f"FloodWait {wait}s — attente...")
            err_json({"type": "flood_wait", "seconds": wait})
            await asyncio.sleep(wait)
        except (ConnectionError, TimeoutError) as e:
            if attempt == retries - 1:
                raise
            delay = base_delay * (2 ** attempt)
            log.warning(f"Tentative {attempt+1}/{retries} échouée: {e} — retry dans {delay}s")
            await asyncio.sleep(delay)
    raise RuntimeError("Toutes les tentatives ont échoué")


# ---------------------------------------------------------------------------
# ACTION : auth_send_code  (étape 1 — envoie l'OTP, retourne phone_code_hash)
# ---------------------------------------------------------------------------
async def action_auth_send_code(api_id: int, api_hash: str, phone: str):
    client = Client(
        name="watchtower_auth",
        api_id=api_id,
        api_hash=api_hash,
        in_memory=True,
    )
    try:
        await client.connect()
        sent = await client.send_code(phone)
        out_json({
            "status": "ok",
            "data": {
                "phone_code_hash": sent.phone_code_hash,
                "type": str(sent.type),
                "timeout": getattr(sent, "timeout", 60),
            }
        })
    except PhoneNumberInvalid:
        out_json({"status": "error", "error": "Numéro de téléphone invalide."})
    except PhoneNumberBanned:
        out_json({"status": "error", "error": "Ce numéro est banni de Telegram."})
    except FloodWait as fw:
        out_json({"status": "error", "error": f"Trop de tentatives. Réessayez dans {fw.value}s."})
    finally:
        try:
            await client.disconnect()
        except Exception:
            pass


# ---------------------------------------------------------------------------
# ACTION : auth_verify_code  (étape 2 — vérifie le code, retourne session_string)
# ---------------------------------------------------------------------------
async def action_auth_verify_code(api_id: int, api_hash: str, phone: str,
                                   phone_code_hash: str, code: str):
    client = Client(
        name="watchtower_auth",
        api_id=api_id,
        api_hash=api_hash,
        in_memory=True,
    )
    try:
        await client.connect()
        try:
            user = await client.sign_in(phone, phone_code_hash, code)
        except SessionPasswordNeeded:
            out_json({"status": "2fa_required",
                      "error": "Ce compte a la vérification en 2 étapes activée."})
            return
        except PhoneCodeInvalid:
            out_json({"status": "error", "error": "Code incorrect."})
            return
        except PhoneCodeExpired:
            out_json({"status": "error", "error": "Code expiré. Renvoie un nouveau code."})
            return

        session_str = await client.export_session_string()
        out_json({
            "status": "ok",
            "data": {
                "session_string": session_str,
                "user_id": user.id if hasattr(user, "id") else None,
                "first_name": getattr(user, "first_name", ""),
                "username": getattr(user, "username", ""),
            }
        })
    finally:
        try:
            await client.disconnect()
        except Exception:
            pass


# ---------------------------------------------------------------------------
# ACTION : auth_check_password  (2FA — vérifie le mot de passe cloud)
# ---------------------------------------------------------------------------
async def action_auth_check_password(api_id: int, api_hash: str, password: str):
    client = Client(
        name="watchtower_auth",
        api_id=api_id,
        api_hash=api_hash,
        in_memory=True,
    )
    try:
        await client.connect()
        try:
            user = await client.check_password(password)
        except PasswordHashInvalid:
            out_json({"status": "error", "error": "Mot de passe 2FA incorrect."})
            return
        except FloodWait as fw:
            out_json({"status": "error", "error": f"Trop de tentatives 2FA. Réessayez dans {fw.value}s."})
            return

        session_str = await client.export_session_string()
        out_json({
            "status": "ok",
            "data": {
                "session_string": session_str,
                "user_id": user.id if hasattr(user, "id") else None,
                "first_name": getattr(user, "first_name", ""),
                "username": getattr(user, "username", ""),
            }
        })
    finally:
        try:
            await client.disconnect()
        except Exception:
            pass


# ---------------------------------------------------------------------------
# ACTION : metadata
# ---------------------------------------------------------------------------
async def action_metadata(api_id: int, api_hash: str, session: str,
                          channel: str, timeout: int):
    client = make_client(api_id, api_hash, session)
    async with client:
        chat = await _retry(lambda: client.get_chat(channel))

        photo_b64 = None
        if chat.photo:
            try:
                buf = BytesIO()
                await _retry(lambda: client.download_media(
                    chat.photo.small_file_id, file=buf))
                photo_b64 = base64.b64encode(buf.getvalue()).decode()
            except Exception as e:
                log.warning(f"Photo du canal non disponible: {e}")

        out_json({
            "status": "ok",
            "data": {
                "id": chat.id,
                "title": chat.title or "",
                "description": chat.description or "",
                "username": f"@{chat.username}" if chat.username else str(chat.id),
                "subscribers": getattr(chat, "members_count", None),
                "cover_b64": photo_b64,
                "is_verified": getattr(chat, "is_verified", False),
                "type": str(chat.type),
            }
        })


# ---------------------------------------------------------------------------
# ACTION : list  — SANS thumbs inline (lazy via action_thumbnail)
# ---------------------------------------------------------------------------
async def action_list(api_id: int, api_hash: str, session: str,
                      channel: str, offset: int, limit: int, timeout: int):
    client = make_client(api_id, api_hash, session)
    items = []
    max_scan = limit * 20

    async with client:
        async for msg in client.get_chat_history(channel, limit=max_scan):
            if not is_supported_doc(msg):
                continue

            doc = msg.document
            fname = doc.file_name or f"file_{msg.id}"
            ext = os.path.splitext(fname)[1].lower()

            # PAS de download thumbnail ici — utiliser action_thumbnail à la demande
            items.append({
                "msg_id": msg.id,
                "title": os.path.splitext(fname)[0],
                "filename": fname,
                "size": doc.file_size or 0,
                "date": msg.date.isoformat() if msg.date else None,
                "has_thumb": bool(doc.thumbs),   # indique si un thumb est disponible
                "mime_type": doc.mime_type or "application/octet-stream",
                "ext": ext,
                "caption": msg.caption or "",
            })

            if len(items) >= offset + limit:
                break

    page_items = items[offset:offset + limit]
    out_json({
        "status": "ok",
        "data": {
            "items": page_items,
            "offset": offset,
            "limit": limit,
            "count": len(page_items),
            "has_more": len(items) >= offset + limit,
        }
    })


# ---------------------------------------------------------------------------
# ACTION : stream  — via temp file (PAS de BytesIO → pas d'OOM)
# ---------------------------------------------------------------------------
async def action_stream(api_id: int, api_hash: str, session: str,
                        channel: str, msg_id: int, chunk_size: int, timeout: int):
    global _stream_cancelled
    client = make_client(api_id, api_hash, session)

    # Fichier temporaire sur disque — évite de charger tout en RAM
    tmp_fd, tmp_path = tempfile.mkstemp(prefix="wt_tg_", suffix=".tmp")
    os.close(tmp_fd)

    try:
        async with client:
            msg = await _retry(lambda: client.get_messages(channel, msg_id))
            if not msg or not msg.document:
                out_json({"status": "error", "error": "Message ou document introuvable"})
                return

            total_size = msg.document.file_size or 0

            # Téléchargement vers disque (Pyrogram gère le chunking réseau)
            await _retry(lambda: client.download_media(msg.document, file_name=tmp_path))

        # Stream depuis le disque → stdout par chunks
        actual_size = os.path.getsize(tmp_path)
        downloaded = 0
        start_time = time.time()

        with open(tmp_path, "rb") as f:
            while True:
                if _stream_cancelled:
                    log.info("Stream annulé proprement")
                    return

                chunk = f.read(chunk_size)
                if not chunk:
                    break

                sys.stdout.buffer.write(chunk)
                sys.stdout.buffer.flush()
                downloaded += len(chunk)

                elapsed = time.time() - start_time
                speed = downloaded / elapsed if elapsed > 0 else 0
                progress = int((downloaded / actual_size) * 100) if actual_size > 0 else 0
                err_json({
                    "type": "progress",
                    "progress": progress,
                    "downloaded": downloaded,
                    "total": actual_size,
                    "speed_bps": int(speed),
                    "speed_human": f"{speed/1024/1024:.1f} MB/s",
                })

    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


# ---------------------------------------------------------------------------
# ACTION : search
# ---------------------------------------------------------------------------
async def action_search(api_id: int, api_hash: str, session: str,
                        channel: str, query: str, limit: int, timeout: int):
    client = make_client(api_id, api_hash, session)
    results = []

    async with client:
        async for msg in client.search_messages(channel, query=query, limit=limit):
            if not is_supported_doc(msg):
                continue
            doc = msg.document
            fname = doc.file_name or f"file_{msg.id}"
            results.append({
                "msg_id": msg.id,
                "title": os.path.splitext(fname)[0],
                "filename": fname,
                "size": doc.file_size or 0,
                "date": msg.date.isoformat() if msg.date else None,
                "mime_type": doc.mime_type or "application/octet-stream",
                "caption": msg.caption or "",
                "has_thumb": bool(doc.thumbs),
            })

    out_json({
        "status": "ok",
        "data": {
            "query": query,
            "results": results,
            "count": len(results),
        }
    })


# ---------------------------------------------------------------------------
# ACTION : thumbnail
# ---------------------------------------------------------------------------
async def action_thumbnail(api_id: int, api_hash: str, session: str,
                           channel: str, msg_id: int, timeout: int):
    client = make_client(api_id, api_hash, session)

    async with client:
        msg = await _retry(lambda: client.get_messages(channel, msg_id))
        if not msg or not msg.document:
            out_json({"status": "error", "error": "Message ou document introuvable"})
            return

        doc = msg.document
        thumb_b64 = None

        if doc.thumbs:
            try:
                buf = BytesIO()
                await _retry(lambda: client.download_media(
                    doc.thumbs[-1].file_id, file=buf))
                thumb_b64 = base64.b64encode(buf.getvalue()).decode()
            except Exception as e:
                log.warning(f"Thumb Telegram non disponible: {e}")

        if not thumb_b64:
            # Essai extraction cover depuis l'archive (téléchargement complet)
            try:
                tmp_fd, tmp_path = tempfile.mkstemp(prefix="wt_thumb_", suffix=".tmp")
                os.close(tmp_fd)
                await _retry(lambda: client.download_media(doc, file_name=tmp_path))
                with open(tmp_path, "rb") as f:
                    archive_bytes = f.read()
                thumb_b64 = _extract_first_image_b64(archive_bytes, doc.file_name or "")
            except Exception as e:
                log.warning(f"Extraction cover depuis archive échouée: {e}")
            finally:
                try:
                    os.unlink(tmp_path)
                except OSError:
                    pass

        out_json({
            "status": "ok",
            "data": {
                "msg_id": msg_id,
                "filename": doc.file_name or f"file_{msg_id}",
                "cover_b64": thumb_b64,
            }
        })


def _extract_first_image_b64(data: bytes, filename: str) -> str | None:
    ext = os.path.splitext(filename)[1].lower()
    try:
        import zipfile
        if ext in (".cbz", ".zip", ".epub"):
            with zipfile.ZipFile(BytesIO(data)) as zf:
                image_names = sorted([
                    n for n in zf.namelist()
                    if n.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))
                    and not n.startswith("__MACOSX")
                ])
                if image_names:
                    img_data = zf.read(image_names[0])
                    return base64.b64encode(img_data).decode()
    except Exception:
        pass

    try:
        import rarfile
        if ext in (".cbr", ".rar"):
            with rarfile.RarFile(BytesIO(data)) as rf:
                image_names = sorted([
                    n for n in rf.namelist()
                    if n.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))
                ])
                if image_names:
                    img_data = rf.read(image_names[0])
                    return base64.b64encode(img_data).decode()
    except Exception:
        pass

    return None


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
def parse_args():
    p = argparse.ArgumentParser(
        description="Watchtower Telegram Source — Pyrogram CLI",
        add_help=True,
    )
    p.add_argument("--action",
                   choices=["auth_send_code", "auth_verify_code", "auth_check_password",
                            "metadata", "list", "stream", "search", "thumbnail"],
                   required=True,
                   help="Action à exécuter")
    p.add_argument("--channel", type=str,
                   help="Username ou ID du canal Telegram (@canal ou -100xxx)")
    p.add_argument("--api_id", type=int, required=True, help="Telegram API ID")
    p.add_argument("--api_hash", type=str, required=True, help="Telegram API Hash")
    p.add_argument("--phone", type=str, help="Numéro de téléphone (format +242...)")
    p.add_argument("--phone_code_hash", type=str, default="",
                   help="Hash retourné par auth_send_code (requis pour auth_verify_code)")
    p.add_argument("--code", type=str, default="",
                   help="Code OTP reçu sur Telegram (requis pour auth_verify_code)")
    p.add_argument("--password", type=str, default="",
                   help="Mot de passe 2FA (requis pour auth_check_password)")
    p.add_argument("--session", type=str, default="",
                   help="Session string Pyrogram (StringSession)")
    p.add_argument("--offset", type=int, default=0, help="Offset pour la liste")
    p.add_argument("--limit", type=int, default=20, help="Nombre d'items par page")
    p.add_argument("--msg_id", type=int, help="ID du message pour stream/thumbnail")
    p.add_argument("--chunk_size", type=int, default=65536,
                   help="Taille des chunks en octets (stream)")
    p.add_argument("--query", type=str, default="", help="Requête de recherche")
    p.add_argument("--timeout", type=int, default=30, help="Timeout réseau (secondes)")
    return p.parse_args()


async def main():
    args = parse_args()

    try:
        if args.action == "auth_send_code":
            if not args.phone:
                out_json({"status": "error", "error": "--phone requis pour auth_send_code"})
                sys.exit(1)
            await action_auth_send_code(args.api_id, args.api_hash, args.phone)

        elif args.action == "auth_verify_code":
            if not args.phone or not args.phone_code_hash or not args.code:
                out_json({"status": "error",
                          "error": "--phone, --phone_code_hash et --code requis"})
                sys.exit(1)
            await action_auth_verify_code(
                args.api_id, args.api_hash, args.phone,
                args.phone_code_hash, args.code)

        elif args.action == "auth_check_password":
            if not args.password:
                out_json({"status": "error", "error": "--password requis pour auth_check_password"})
                sys.exit(1)
            await action_auth_check_password(args.api_id, args.api_hash, args.password)

        elif args.action == "metadata":
            if not args.channel:
                out_json({"status": "error", "error": "--channel requis"})
                sys.exit(1)
            await action_metadata(args.api_id, args.api_hash, args.session,
                                  args.channel, args.timeout)

        elif args.action == "list":
            if not args.channel:
                out_json({"status": "error", "error": "--channel requis"})
                sys.exit(1)
            await action_list(args.api_id, args.api_hash, args.session,
                              args.channel, args.offset, args.limit, args.timeout)

        elif args.action == "stream":
            if not args.channel or not args.msg_id:
                out_json({"status": "error", "error": "--channel et --msg_id requis"})
                sys.exit(1)
            await action_stream(args.api_id, args.api_hash, args.session,
                                args.channel, args.msg_id, args.chunk_size, args.timeout)

        elif args.action == "search":
            if not args.channel:
                out_json({"status": "error", "error": "--channel requis"})
                sys.exit(1)
            await action_search(args.api_id, args.api_hash, args.session,
                                args.channel, args.query, args.limit, args.timeout)

        elif args.action == "thumbnail":
            if not args.channel or not args.msg_id:
                out_json({"status": "error", "error": "--channel et --msg_id requis"})
                sys.exit(1)
            await action_thumbnail(args.api_id, args.api_hash, args.session,
                                   args.channel, args.msg_id, args.timeout)

        else:
            out_json({"status": "error", "error": f"Action non reconnue: {args.action}"})
            sys.exit(1)

    except AuthKeyUnregistered:
        out_json({"status": "error", "error": "Session expirée. Ré-authentifiez-vous."})
        sys.exit(1)
    except UserDeactivated:
        out_json({"status": "error", "error": "Compte Telegram désactivé."})
        sys.exit(1)
    except Exception as e:
        out_json({"status": "error", "error": str(e)})
        log.exception("Erreur non gérée")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
