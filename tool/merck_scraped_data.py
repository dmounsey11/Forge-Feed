import json
import os
import re
import time
from typing import Any, Dict, Optional
import requests
import urllib3
from bs4 import BeautifulSoup

# Suppress SSL certificate warning messages
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/125.0.0.0 Safari/537.36"
    )
}
REQUEST_DELAY = 1.5


def slugify(text: str) -> str:
    """Generates a clean JSON ID string from an animal name (e.g., 'spec_nutrition_in_reptiles')."""
    cleaned = re.sub(r"[^\w\s-]", "", text).strip().lower()
    return f"spec_{re.sub(r'[-\s]+', '_', cleaned)}"


def extract_float(text: str) -> Optional[float]:
    """Extracts numerical figures (e.g., converts '22%' or '22 g/kg' to float 22.0)."""
    match = re.search(r"[-+]?\d*\.\d+|\d+", text)
    return float(match.group()) if match else None


def parse_merck_page(url: str) -> Optional[Dict[str, Any]]:
    try:
        response = requests.get(url, headers=HEADERS, timeout=10, verify=False)
        if response.status_code != 200:
            print(f"  -> HTTP Error {response.status_code} for {url}")
            return None

        soup = BeautifulSoup(response.text, "html.parser")

        # Get topic title
        title_tag = soup.find("h1")
        if not title_tag:
            return None

        raw_title = title_tag.get_text(strip=True)
        animal_id = slugify(raw_title)

        entry = {
            "id": animal_id,
            "name": raw_title,
            "category": "Exotic Animals",
            "description": f"Captive profile for {raw_title}.",
            "veterinarySource": "Merck Veterinary Manual",
            "caToPRatio": "1.5:1",
            "vitaminD3IU": None,
            "requirements": {
                "crudeProtein": None,
                "crudeFat": None,
                "crudeFiber": None,
                "calcium": None,
                "phosphorus": None,
            },
        }

        # Scan standard HTML tables for nutrient keys
        tables = soup.find_all("table")
        for table in tables:
            rows = table.find_all("tr")
            for row in rows:
                cols = [c.get_text(strip=True) for c in row.find_all(["td", "th"])]
                if len(cols) < 2:
                    continue

                label = cols[0].lower()
                value = cols[1]

                if "crude protein" in label or "protein" in label:
                    entry["requirements"]["crudeProtein"] = extract_float(value)
                elif "crude fat" in label or "fat" in label:
                    entry["requirements"]["crudeFat"] = extract_float(value)
                elif "crude fiber" in label or "fiber" in label:
                    entry["requirements"]["crudeFiber"] = extract_float(value)
                elif "calcium" in label:
                    entry["requirements"]["calcium"] = extract_float(value)
                elif "phosphorus" in label:
                    entry["requirements"]["phosphorus"] = extract_float(value)
                elif "vitamin d" in label:
                    entry["vitaminD3IU"] = extract_float(value)
                elif "ca:p" in label or "calcium:phosphorus" in label:
                    entry["caToPRatio"] = value

        return entry

    except Exception as e:
        print(f"  -> Error parsing {url}: {e}")
        return None


def run_merck_scraper(
    target_urls: list[str],
    output_filename: str = "assets/data/merck_scraped_data.json",
):
    results = []
    os.makedirs(os.path.dirname(output_filename), exist_ok=True)

    for index, url in enumerate(target_urls, start=1):
        print(f"[{index}/{len(target_urls)}] Scraping: {url}...")
        parsed_data = parse_merck_page(url)

        if parsed_data:
            results.append(parsed_data)

        time.sleep(REQUEST_DELAY)

    with open(output_filename, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    print(
        f"\nScraping complete. Successfully saved {len(results)} entries to {output_filename}"
    )


if __name__ == "__main__":
    # Corrected URLs for Merck Veterinary Manual
    target_urls = [
        "https://www.merckvetmanual.com/management-and-nutrition/nutrition-exotic-and-zoo-animals/nutrition-in-rodents-and-lagomorphs",
        "https://www.merckvetmanual.com/management-and-nutrition/nutrition-exotic-and-zoo-animals/nutrition-in-reptiles",
        "https://www.merckvetmanual.com/management-and-nutrition/nutrition-exotic-and-zoo-animals/nutrition-in-alligators-crocodiles-and-other-crocodilians",
        "https://www.merckvetmanual.com/management-and-nutrition/nutrition-exotic-and-zoo-animals/hand-rearing-zoo-mammals",
    ]

    run_merck_scraper(target_urls)