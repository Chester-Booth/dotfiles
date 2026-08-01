import json
import unittest
from pathlib import Path


class EmojiDatasetTests(unittest.TestCase):
    def test_unicode_dataset_has_all_groups_and_thousands_of_entries(self):
        path = Path(__file__).parents[1] / "quickshell/.config/quickshell/blox/assets/emoji.json"
        document = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual("17.0", document["unicode_emoji_version"])
        self.assertEqual("48.2", document["cldr_version"])
        self.assertGreater(len(document["items"]), 3900)
        self.assertEqual(
            {
                "Activities", "Animals & Nature", "Flags", "Food & Drink",
                "Objects", "People & Body", "Smileys & Emotion", "Symbols",
                "Travel & Places",
            },
            {item["category"] for item in document["items"]},
        )
        values = {item["value"] for item in document["items"]}
        self.assertIn("👰‍♀️", values)
        self.assertIn("🫩", values)
        self.assertIn("∑", values)
        self.assertNotIn("✌", values)
        self.assertIn("✌️", values)
        self.assertGreater(len(document["items"]), 6000)
        self.assertLess(len(document["items"]), 7000)
        grinning = next(item for item in document["items"] if item["value"] == "😀")
        self.assertIn("happy", grinning["keywords"])


if __name__ == "__main__":
    unittest.main()
