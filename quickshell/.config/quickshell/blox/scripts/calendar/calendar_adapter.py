#!/usr/bin/env python3
"""JSON command adapter between Quickshell and Google Calendar via gcalcli."""

from __future__ import annotations

import argparse
import json
import os
import sys
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from calendar_store import CalendarStore


def envelope(store, data=None, error=None):
    return {"ok": error is None, "revision": store.revision, "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"), "data": data if error is None else None, "error": error}


def fail(code, message, retryable=False, details=None):
    return {"code": code, "message": message, "retryable": retryable, "details": details or {}}


def read_payload():
    line = sys.stdin.readline()
    if not line:
        raise ValueError("A JSON request line is required")
    return json.loads(line)


def allow_list(calendars):
    path = Path.home() / ".config" / "quickshell" / "blox" / "calendar.json"
    try:
        allowed = set(json.loads(path.read_text()).get("writable_calendar_ids", []))
    except (OSError, ValueError):
        primary = next((c["id"] for c in calendars if c.get("primary") and c.get("accessRole") in ("writer", "owner")), None)
        allowed = {primary} if primary else set()
    for calendar in calendars:
        calendar["write_allowed"] = calendar["id"] in allowed and calendar.get("accessRole") in ("writer", "owner")
    return calendars


def build_gcal_client():
    """Keep the private gcalcli import and version guard in one place."""
    try:
        import gcalcli
        from importlib.metadata import version
    except (ImportError, ModuleNotFoundError) as exc:
        raise RuntimeError("gcalcli is not installed") from exc
    if version("gcalcli") != "4.5.1":
        raise RuntimeError(f'unsupported gcalcli version {version("gcalcli")}; expected 4.5.1')
    # gcalcli does not expose a stable library constructor. Importing here keeps
    # snapshots fast and keeps the private dependency in this function.
    from gcalcli.argparsers import get_argument_parser
    from gcalcli.gcal import GoogleCalendarInterface
    parser = get_argument_parser()
    options = parser.parse_args(["list"])
    if not hasattr(options, "ignore_calendars"):
        options.ignore_calendars = []
    return GoogleCalendarInterface(**vars(options))


def service_from_client(client):
    getter = getattr(client, "get_cal_service", None)
    if getter:
        oauth_path = client.data_file_path("oauth")
        if not oauth_path.exists():
            raise RuntimeError("auth_required: run gcalcli once to sign in")
        return getter()
    for name in ("cal_service", "service"):
        value = getattr(client, name, None)
        if value:
            return value
    raise RuntimeError("unsupported_gcalcli: Calendar API service was not found")


def api_execute(request, etag=None):
    if etag and hasattr(request, "headers"):
        request.headers["If-Match"] = etag
    return request.execute()


def refresh(store, start, end):
    service = service_from_client(build_gcal_client())
    if store.colours_stale():
        provider_colours = service.colors().get().execute().get("event", {})
        if provider_colours:
            store.replace_colours(provider_colours)
    calendars, token = [], None
    while True:
        page = service.calendarList().list(pageToken=token).execute()
        calendars.extend(page.get("items", []))
        token = page.get("nextPageToken")
        if not token:
            break
    calendars = allow_list([c for c in calendars if c.get("selected") is True])
    failures = []
    for calendar in calendars:
        items, token = [], None
        try:
            while True:
                page = service.events().list(calendarId=calendar["id"], timeMin=start, timeMax=end, singleEvents=True, showDeleted=False, pageToken=token).execute()
                items.extend(page.get("items", []))
                token = page.get("nextPageToken")
                if not token:
                    break
            store.replace_calendar_slice(calendar, items, start, end)
        except Exception as exc:  # Google client exceptions vary by dependency version.
            failures.append({"calendar_id": calendar["id"], "message": str(exc)})
    return {"partial_failures": failures, **store.snapshot(start, end)}


def mutate(store, command, payload):
    calendar_id = payload["calendar_id"]
    store.assert_writable(calendar_id, None if command == "create" else payload.get("event_id"))
    if command == "move":
        store.assert_writable(payload["destination_id"])
    service = service_from_client(build_gcal_client())
    events = service.events()
    if command == "create":
        body = payload["event"]
        body.setdefault("id", uuid.uuid4().hex)
        result = api_execute(events.insert(calendarId=calendar_id, body=body, sendUpdates="all" if payload.get("send_updates") else "none"))
    elif command == "update":
        result = api_execute(events.patch(calendarId=calendar_id, eventId=payload["event_id"], body=payload["changes"], sendUpdates="all" if payload.get("send_updates") else "none"), payload.get("etag"))
    elif command == "delete":
        scope = payload.get("scope", "instance")
        target_id = payload["event_id"]
        if scope in ("series", "following"):
            target_id = payload.get("master_id") or target_id
            master = api_execute(events.get(calendarId=calendar_id, eventId=target_id))
            if scope == "following":
                original = payload.get("original_start")
                if isinstance(original, str):
                    try:
                        original = json.loads(original)
                    except ValueError:
                        pass
                value = original.get("dateTime") or original.get("date") if isinstance(original, dict) else original
                if not value:
                    raise ValueError("The recurring instance start is missing")
                until = (_aware_datetime(value) - timedelta(seconds=1)).astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                rules = master.get("recurrence", [])
                if not rules:
                    raise ValueError("The recurring series rule is missing")
                parts = [part for part in rules[0].split(";") if not part.startswith(("UNTIL=", "COUNT="))]
                parts.append(f"UNTIL={until}")
                result = api_execute(events.patch(calendarId=calendar_id, eventId=target_id, body={"recurrence": [";".join(parts)]}), master.get("etag"))
            else:
                api_execute(events.delete(calendarId=calendar_id, eventId=target_id, sendUpdates="all" if payload.get("send_updates") else "none"), master.get("etag"))
                result = {"id": target_id, "status": "cancelled"}
        else:
            api_execute(events.delete(calendarId=calendar_id, eventId=target_id, sendUpdates="all" if payload.get("send_updates") else "none"), payload.get("etag"))
            result = {"id": target_id, "status": "cancelled"}
        store.delete_event(calendar_id, payload["event_id"])
    elif command == "move":
        source_id = calendar_id
        result = api_execute(events.move(calendarId=calendar_id, eventId=payload["event_id"], destination=payload["destination_id"]), payload.get("etag"))
        calendar_id = payload["destination_id"]
        if payload.get("changes"):
            result = api_execute(events.patch(calendarId=calendar_id, eventId=result["id"], body=payload["changes"], sendUpdates="all" if payload.get("send_updates") else "none"), result.get("etag"))
        store.delete_event(source_id, payload["event_id"])
    else:
        raise ValueError(f"Unsupported mutation: {command}")
    if result.get("start"):
        with store.transaction():
            store.upsert_event(calendar_id, result)
            store.bump_revision()
    return {"event": result}


def recurrence_info(payload):
    service = service_from_client(build_gcal_client())
    events = service.events()
    calendar_id = payload["calendar_id"]
    master_id = payload.get("master_id") or payload.get("event_id")
    master = events.get(calendarId=calendar_id, eventId=master_id).execute()
    original = payload.get("original_start_ms")
    if original is None:
        source = payload.get("original_start") or master.get("start", {}).get("dateTime") or master.get("start", {}).get("date")
        if isinstance(source, dict):
            source = source.get("dateTime") or source.get("date")
        original_dt = _aware_datetime(source)
    else:
        original_dt = datetime.fromtimestamp(original / 1000, tz=timezone.utc)
    after = (original_dt + timedelta(seconds=1)).isoformat().replace("+00:00", "Z")
    later = events.instances(calendarId=calendar_id, eventId=master_id, timeMin=after, maxResults=1, showDeleted=False).execute().get("items", [])
    master_start = master.get("start", {}).get("dateTime") or master.get("start", {}).get("date")
    master_dt = _aware_datetime(master_start)
    return {"master_etag": master.get("etag"), "has_earlier": master_dt < original_dt, "has_later": bool(later), "master": {"id": master_id, "etag": master.get("etag"), "recurrence": master.get("recurrence", [])}}


def _aware_datetime(value):
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("doctor", "snapshot", "refresh", "recurrence-info", "create", "update", "move", "delete"))
    parser.add_argument("--start")
    parser.add_argument("--end")
    parser.add_argument("--database")
    args = parser.parse_args(argv)
    store = CalendarStore(args.database)
    try:
        if args.command == "snapshot":
            if not args.start or not args.end:
                raise ValueError("snapshot needs --start and --end")
            output = envelope(store, store.snapshot(args.start, args.end))
        elif args.command == "doctor":
            try:
                service_from_client(build_gcal_client())
                output = envelope(store, {"gcalcli": "4.5.1", "database": str(store.path), "api": "ready"})
            except Exception as exc:
                output = envelope(store, error=fail("auth_or_client_error", str(exc)))
        elif args.command == "refresh":
            output = envelope(store, refresh(store, args.start, args.end))
        elif args.command == "recurrence-info":
            output = envelope(store, recurrence_info(read_payload()))
        else:
            output = envelope(store, mutate(store, args.command, read_payload()))
    except (ValueError, PermissionError) as exc:
        output = envelope(store, error=fail("invalid_request", str(exc)))
    except Exception as exc:
        status = getattr(getattr(exc, "resp", None), "status", None)
        if status == 412:
            code = "etag_conflict"
        elif "auth_required" in str(exc):
            code = "auth_required"
        else:
            code = "unsupported_gcalcli" if "unsupported" in str(exc).lower() else "provider_error"
        output = envelope(store, error=fail(code, str(exc), retryable=code == "provider_error"))
    finally:
        store.close()
    print(json.dumps(output, separators=(",", ":")))
    return 0 if output["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
