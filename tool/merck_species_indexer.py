import json
import os
import re
import time
import requests
import urllib3
from bs4 import BeautifulSoup

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/125.0.0.0 Safari/537.36"
    )
}

# Key category index pages on Merck Vet Manual
CATEGORY_INDEX_URLS = [
    "https://www.merckvetmanual.com/exotic-and-laboratory-animals",
    "https://www.merckvetmanual.com/management-and-nutrition/nutrition-exotic-and-zoo-animals",
    "https://www.merckvetmanual.com/poultry",
]

def slugify(text: str) -> str:
    cleaned = re.sub(r"[^\w\s-]", "", text).strip().lower()
    return f"spec_{re.sub(r'[-\s]+', '_', cleaned)}"

def discover_species_from_index(category_url: str) -> list[dict]:
    """Extracts all animal/topic links found on a category listing page."""
    discovered = []
    try:
        response = requests.get(category_url, headers=HEADERS, timeout=10, verify=False)
        if response.status_code != 200:
            print(f"Failed to load category page: {category_url}")
            return discovered

        soup = BeautifulSoup(response.text, "html.parser")

        # Find main content container links
        for anchor in soup.find_all("a", href=True):
            href = anchor["href"]
            text = anchor.get_text(strip=True)

            # Filter for topic links within relevant paths
            if any(path in href for path in ["/exotic-and-laboratory-animals/", "/nutrition-exotic-and-zoo-animals/", "/poultry/"]):
                if text and len(text) > 3 and not any(skip in text.lower() for skip in ["overview", "view all", "table", "figure"]):
                    
                    full_url = href if href.startswith("http") else f"https://www.merckvetmanual.com{href}"
                    
                    entry = {
                        "id": slugify(text),
                        "name": text,
                        "category": "Exotic Animals",
                        "description": f"Captive profile for {text}.",
                        "veterinarySource": "Merck Veterinary Manual",
                        "sourceUrl": full_url,
                        "requirements": {}  # To be populated during nutrient enrichment pass
                    }
                    discovered.append(entry)

    except Exception as e:
        print(f"Error indexing {category_url}: {e}")

    return discovered

def run_indexer(output_filename: str = "assets/data/merck_species_index.json"):
    os.makedirs(os.path.dirname(output_filename), exist_ok=True)
    all_animals = {}

    for url in CATEGORY_INDEX_URLS:
        print(f"Indexing category: {url}...")
        animals = discover_species_from_index(url)
        for animal in animals:
            # Prevent duplicate entries by ID
            all_animals[animal["id"]] = animal
        time.sleep(1.0)

    results = list(all_animals.values())

    with open(output_filename, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    print(f"\nIndexing complete! Found {len(results)} unique species/topics.")
    print(f"Master list saved to: {output_filename}")

if __name__ == "__main__":
    run_indexer()