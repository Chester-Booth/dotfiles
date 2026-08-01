#!/usr/bin/env python3
"""Generate the tracked launcher emoji dataset from Unicode emoji-test.txt."""

import argparse
import json
import re
import xml.etree.ElementTree as ElementTree
from pathlib import Path


def read_annotations(paths: list[Path]) -> dict[str, dict[str, str]]:
    annotations: dict[str, dict[str, str]] = {}
    for path in paths:
        if not path:
            continue
        for element in ElementTree.parse(path).iterfind(".//annotation"):
            value = element.attrib.get("cp", "")
            if not value or not element.text:
                continue
            entry = annotations.setdefault(value, {"name": "", "keywords": ""})
            text = " ".join(element.text.split())
            if element.attrib.get("type") == "tts":
                entry["name"] = text
            else:
                entry["keywords"] = " ".join(part.strip() for part in text.split("|") if part.strip())
    return annotations


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("unicode_data", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--annotations", type=Path)
    parser.add_argument("--annotations-derived", type=Path)
    parser.add_argument("--cldr-version", default="")
    args = parser.parse_args()
    annotations = read_annotations([args.annotations, args.annotations_derived])
    group = ""
    items = []
    version = ""
    for line in args.source.read_text(encoding="utf-8").splitlines():
        if line.startswith("# Version:"):
            version = line.split(":", 1)[1].strip()
        elif line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
        elif "; fully-qualified" in line:
            match = re.match(r"^([0-9A-F ]+)\s*;\s*fully-qualified\s*#\s*(\S+)\s+E[\d.]+\s+(.+)$", line)
            if not match:
                continue
            value = match.group(2)
            annotation = annotations.get(value, annotations.get(value.replace("\ufe0f", ""), {}))
            name = annotation.get("name") or match.group(3)
            keywords = annotation.get("keywords") or match.group(3).replace("-", " ")
            items.append({
                "value": value,
                "name": name,
                "keywords": keywords,
                "category": group,
            })
    emoji_values = {item["value"] for item in items}
    emoji_text_forms = {value.replace("\ufe0f", "").replace("\ufe0e", "") for value in emoji_values}
    symbol_ranges = (
        (0x00A1, 0x00BF),
        (0x2010, 0x206F),
        (0x20A0, 0x20CF),
        (0x2100, 0x218F),
        (0x2190, 0x2BFF),
    )
    for line in args.unicode_data.read_text(encoding="utf-8").splitlines():
        fields = line.split(";")
        if len(fields) < 3 or not fields[1] or not fields[2].startswith(("S", "P")):
            continue
        codepoint = int(fields[0], 16)
        if not any(start <= codepoint <= end for start, end in symbol_ranges):
            continue
        value = chr(codepoint)
        if value in emoji_values or value in emoji_text_forms or fields[1].startswith("<"):
            continue
        name = fields[1].lower().replace("-", " ")
        items.append({"value": value, "name": name, "keywords": name, "category": "Symbols"})
    document = {
        "schema_version": 1,
        "unicode_emoji_version": version,
        "source": "https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt",
        "unicode_data_source": "https://www.unicode.org/Public/17.0.0/ucd/UnicodeData.txt",
        "cldr_version": args.cldr_version,
        "cldr_annotation_source": "https://github.com/unicode-org/cldr/tree/release-48-2/common/annotations",
        "cldr_derived_annotation_source": "https://github.com/unicode-org/cldr/tree/release-48-2/common/annotationsDerived",
        "licence": "https://www.unicode.org/license.txt",
        "items": items,
    }
    args.output.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
