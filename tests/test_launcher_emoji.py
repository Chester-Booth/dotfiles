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

    def test_dataset_uses_picker_category_and_symbol_order(self):
        path = Path(__file__).parents[1] / "quickshell/.config/quickshell/blox/assets/emoji.json"
        items = json.loads(path.read_text(encoding="utf-8"))["items"]
        category_order = list(dict.fromkeys(item["category"] for item in items))
        self.assertEqual(
            [
                "Smileys & Emotion", "People & Body", "Animals & Nature", "Food & Drink",
                "Activities", "Travel & Places", "Objects", "Flags", "Symbols",
            ],
            category_order,
        )

        smileys = [item for item in items if item["category"] == "Smileys & Emotion"]
        subcategories = list(dict.fromkeys(item["subcategory"] for item in smileys))
        self.assertLess(subcategories.index("cat-face"), subcategories.index("face-costume"))
        self.assertLess(subcategories.index("monkey-face"), subcategories.index("heart"))
        self.assertLess(subcategories.index("heart"), subcategories.index("emotion"))

        symbols = [item for item in items if item["category"] == "Symbols"]
        first_text_symbol = next(index for index, item in enumerate(symbols) if item["subcategory"].startswith("text-"))
        self.assertTrue(all(not item["subcategory"].startswith("text-") for item in symbols[:first_text_symbol]))
        self.assertLess(
            next(index for index, item in enumerate(symbols) if item["value"] == "‽"),
            next(index for index, item in enumerate(symbols) if item["subcategory"] == "text-shape"),
        )
        self.assertLess(
            next(index for index, item in enumerate(symbols) if item["subcategory"] == "text-shape"),
            next(index for index, item in enumerate(symbols) if item["subcategory"] == "text-arrow"),
        )


if __name__ == "__main__":
    unittest.main()
