#!/usr/bin/env python3
import argparse
import hashlib
import json
import mimetypes
import os
import shutil
import subprocess
import time
from pathlib import Path


STATE_ROOT = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell/blox/clipboard"
IMAGE_ROOT = STATE_ROOT / "images"
STATE_FILE = STATE_ROOT / "history.json"
MAX_ITEMS = 80
PREVIEW_CHARS = 600


def ensure_dirs():
    IMAGE_ROOT.mkdir(parents=True, exist_ok=True)


def load_history():
    ensure_dirs()
    if not STATE_FILE.exists():
        return []
    try:
        data = json.loads(STATE_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return []
    return data if isinstance(data, list) else []


def save_history(items):
    ensure_dirs()
    STATE_FILE.write_text(json.dumps(items[:MAX_ITEMS], ensure_ascii=False, indent=2))


def now_ms():
    return int(time.time() * 1000)


def run_bytes(args):
    try:
        return subprocess.check_output(args, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return b""


def list_types():
    raw = run_bytes(["wl-paste", "--list-types"])
    return raw.decode("utf-8", "replace").splitlines()


def fingerprint(kind, mime, data):
    return hashlib.sha256(kind.encode() + b"\0" + mime.encode() + b"\0" + data).hexdigest()


def prune_images(items):
    live = {Path(item.get("path", "")).name for item in items if item.get("kind") == "image" and item.get("path")}
    for path in IMAGE_ROOT.glob("*.png"):
        if path.name not in live:
            path.unlink(missing_ok=True)


def normalize_text(raw):
    return raw.decode("utf-8", "replace").replace("\x00", "").strip()


def add_item(kind, mime, payload, text=None, path=None):
    if not payload:
        return
    items = load_history()
    item_id = fingerprint(kind, mime, payload)
    previous = next((item for item in items if item.get("id") == item_id), {})
    items = [item for item in items if item.get("id") != item_id]
    item = {
        "id": item_id,
        "kind": kind,
        "mime": mime,
        "pinned": previous.get("pinned", False),
        "created": now_ms(),
    }
    if text is not None:
        item["text"] = text[:PREVIEW_CHARS]
        item["size"] = len(text)
    if path is not None:
        item["path"] = str(path)
        item["size"] = len(payload)
    items.insert(0, item)
    pinned = [item for item in items if item.get("pinned")]
    rest = [item for item in items if not item.get("pinned")]
    save_history((pinned + rest)[:MAX_ITEMS])
    prune_images(load_history())


def capture():
    types = list_types()
    image_type = next((mime for mime in types if mime.startswith("image/")), "")
    if image_type:
        payload = run_bytes(["wl-paste", "--type", image_type])
        if not payload:
            return
        item_id = fingerprint("image", image_type, payload)
        path = IMAGE_ROOT / f"{item_id}.png"
        if image_type == "image/png":
            path.write_bytes(payload)
        else:
            proc = subprocess.run(
                ["magick", "-", "png:" + str(path)],
                input=payload,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if proc.returncode != 0:
                path.write_bytes(payload)
        add_item("image", image_type, payload, path=path)
        return

    text_type = next((mime for mime in types if mime.startswith("text/") or mime == "STRING" or mime == "UTF8_STRING"), "")
    if text_type:
        payload = run_bytes(["wl-paste", "--type", text_type])
        text = normalize_text(payload)
        if text:
            add_item("text", "text/plain", text.encode("utf-8"), text=text)


def public_item(item):
    result = dict(item)
    if result.get("kind") == "image" and result.get("path"):
        result["url"] = Path(result["path"]).resolve().as_uri()
        result["label"] = "Image"
    else:
        result["label"] = (result.get("text") or "").splitlines()[0][:90] or "Text"
    return result


def list_items():
    print(json.dumps({"items": [public_item(item) for item in load_history()]}, ensure_ascii=False))


def find_item(item_id):
    return next((item for item in load_history() if item.get("id") == item_id), None)


def copy_item(item):
    if item.get("kind") == "image" and item.get("path"):
        mime = item.get("mime") or mimetypes.guess_type(item["path"])[0] or "image/png"
        with open(item["path"], "rb") as handle:
            subprocess.run(["wl-copy", "--type", mime], stdin=handle, check=False)
    else:
        subprocess.run(["wl-copy"], input=(item.get("text") or "").encode("utf-8"), check=False)


def paste_active():
    time.sleep(0.08)
    if shutil.which("wtype"):
        subprocess.run(["wtype", "-M", "ctrl", "v", "-m", "ctrl"], check=False)
    elif shutil.which("ydotool"):
        subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"], check=False)


def select(item_id, paste):
    item = find_item(item_id)
    if not item:
        return 1
    copy_item(item)
    if paste:
        paste_active()
    return 0


def delete(item_id):
    items = load_history()
    target = next((item for item in items if item.get("id") == item_id), None)
    items = [item for item in items if item.get("id") != item_id]
    save_history(items)
    if target and target.get("kind") == "image" and target.get("path"):
        Path(target["path"]).unlink(missing_ok=True)


def toggle_pin(item_id):
    items = load_history()
    for item in items:
        if item.get("id") == item_id:
            item["pinned"] = not item.get("pinned", False)
            item["created"] = now_ms()
            break
    save_history(sorted(items, key=lambda item: (not item.get("pinned", False), -int(item.get("created", 0)))))


def clear():
    items = [item for item in load_history() if item.get("pinned")]
    save_history(items)
    prune_images(items)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["capture", "list", "select", "delete", "pin", "clear"])
    parser.add_argument("id", nargs="?")
    parser.add_argument("--paste", action="store_true")
    args = parser.parse_args()

    if args.command == "capture":
        capture()
    elif args.command == "list":
        list_items()
    elif args.command == "select" and args.id:
        return select(args.id, args.paste)
    elif args.command == "delete" and args.id:
        delete(args.id)
    elif args.command == "pin" and args.id:
        toggle_pin(args.id)
    elif args.command == "clear":
        clear()
    else:
        parser.error("missing item id")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
