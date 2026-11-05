# saleti

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## The python script used to get the json file for the mushaf data

import json
import urllib.request
import time

def fetch_mushaf_json(output_filename="mushaf_complete.json"):
mushaf_data = {}

    # 1. Fetch Surah metadata
    print("Fetching Surah metadata...")
    surah_meta_url = "https://api.quran.com/api/v4/chapters"
    req = urllib.request.Request(surah_meta_url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        surahs_info = {s["id"]: s for s in json.loads(response.read().decode())["chapters"]}

    print("Fetching pages 1 to 604 from Quran.com API...")

    for page_num in range(1, 605):
        print(f"Processing Page {page_num}/604...", end="\r")

        # 2. Reliable v4 Verses-by-Page endpoint with word-level line numbers
        page_url = (
            f"https://api.quran.com/api/v4/verses/by_page/{page_num}"
            f"?words=true&word_fields=text_uthmani,line_number,char_type_name"
        )
        req = urllib.request.Request(page_url, headers={'User-Agent': 'Mozilla/5.0'})

        try:
            with urllib.request.urlopen(req) as response:
                raw_data = json.loads(response.read().decode())
        except Exception as e:
            print(f"\nError fetching page {page_num}: {e}")
            time.sleep(1)
            continue

        page_surahs = set()
        lines_dict = {}

        # 3. Process verses and extract word positions
        for verse in raw_data.get("verses", []):
            surah_id = int(verse["verse_key"].split(":")[0])
            page_surahs.add(surahs_info[surah_id]["name_simple"])

            for w in verse.get("words", []):
                line_no = w.get("line_number")
                if not line_no:
                    continue
                if line_no not in lines_dict:
                    lines_dict[line_no] = []

                lines_dict[line_no].append({
                    "char_type": w.get("char_type_name"),
                    "surah": surah_id,
                    "ayah": verse.get("verse_number"),
                    "text": w.get("text_uthmani")
                })

        formatted_lines = []

        # 4. Reconstruct lines into structured objects
        for line_no in sorted(lines_dict.keys()):
            line_items = lines_dict[line_no]
            first_type = line_items[0]["char_type"]

            if first_type == "surah_name":
                surah_id = line_items[0]["surah"]
                meta = surahs_info.get(surah_id, {})
                formatted_lines.append({
                    "line_number": line_no,
                    "type": "surah_header",
                    "surah_number": surah_id,
                    "name_ar": meta.get("name_arabic", ""),
                    "name_en": meta.get("name_simple", ""),
                    "revelation_place": meta.get("revelation_place", ""),
                    "total_ayahs": meta.get("verses_count", 0)
                })
            elif first_type == "bismillah":
                formatted_lines.append({
                    "line_number": line_no,
                    "type": "basmalah",
                    "text": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"
                })
            else:
                line_elements = []
                for item in line_items:
                    if item["char_type"] == "end":
                        line_elements.append({
                            "type": "ayah_end",
                            "surah": item["surah"],
                            "ayah": item["ayah"],
                            "symbol": "۝",
                            "number_ar": item["text"]
                        })
                    elif item["char_type"] == "word":
                        line_elements.append({
                            "type": "word",
                            "surah": item["surah"],
                            "ayah": item["ayah"],
                            "text": item["text"]
                        })

                formatted_lines.append({
                    "line_number": line_no,
                    "type": "text",
                    "elements": line_elements
                })

        mushaf_data[str(page_num)] = {
            "page_number": page_num,
            "surahs_on_page": list(page_surahs),
            "lines": formatted_lines
        }

        time.sleep(0.05)

    print("\nWriting data to JSON file...")
    with open(output_filename, "w", encoding="utf-8") as f:
        json.dump(mushaf_data, f, ensure_ascii=False, indent=2)

    print(f"Success! Complete Mushaf exported to {output_filename}")

if **name** == "**main**":
fetch_mushaf_json()
