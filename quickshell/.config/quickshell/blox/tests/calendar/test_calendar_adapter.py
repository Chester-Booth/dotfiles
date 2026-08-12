import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT_DIR = Path(__file__).resolve().parents[2] / "scripts" / "calendar"
sys.path.insert(0, str(SCRIPT_DIR))
import calendar_adapter
from calendar_store import CalendarStore


class FakeRequest:
    def __init__(self, result):
        self.result = result
        self.headers = {}

    def execute(self):
        return self.result


class FakeEvents:
    def __init__(self):
        self.last = None

    def patch(self, **kwargs):
        self.last = FakeRequest({
            "id": kwargs["eventId"], "etag": "new", "summary": kwargs["body"].get("summary", "Event"),
            "start": {"dateTime": "2026-08-12T09:00:00Z"},
            "end": {"dateTime": "2026-08-12T10:00:00Z"},
        })
        return self.last


class FakeService:
    def __init__(self):
        self.events_api = FakeEvents()

    def events(self):
        return self.events_api


class CalendarAdapterTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = CalendarStore(Path(self.temp.name) / "calendar.sqlite3")

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def seed(self, role="owner", allowed=True):
        calendar = {"id": "main", "summary": "Main", "accessRole": role, "write_allowed": allowed}
        event = {"id": "event", "etag": "old", "summary": "Event", "start": {"dateTime": "2026-08-12T09:00:00Z"}, "end": {"dateTime": "2026-08-12T10:00:00Z"}}
        self.store.replace_calendar_slice(calendar, [event], "2026-08-01T00:00:00Z", "2026-09-01T00:00:00Z")

    def test_adapter_rejects_read_only_before_building_client(self):
        self.seed(role="reader")
        with patch.object(calendar_adapter, "build_gcal_client") as build:
            with self.assertRaises(PermissionError):
                calendar_adapter.mutate(self.store, "update", {"calendar_id": "main", "event_id": "event", "changes": {"summary": "No"}})
        build.assert_not_called()

    def test_update_sends_if_match(self):
        self.seed()
        service = FakeService()
        with patch.object(calendar_adapter, "build_gcal_client", return_value=object()), patch.object(calendar_adapter, "service_from_client", return_value=service):
            result = calendar_adapter.mutate(self.store, "update", {"calendar_id": "main", "event_id": "event", "etag": "old", "changes": {"summary": "Changed"}})
        self.assertEqual(service.events_api.last.headers["If-Match"], "old")
        self.assertEqual(result["event"]["summary"], "Changed")


if __name__ == "__main__":
    unittest.main()
