import json
import re
import os
import requests
from bs4 import BeautifulSoup

# Ensure output directory exists
OUTPUT_DIR = os.path.join("assets", "data")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Helper regex engine to parse Guaranteed Analysis tables from raw HTML or text
def parse_guaranteed_analysis(text):
    metrics = {
        "moisturePct": 12.0,  # Default standard air-dried feed moisture
        "crudeProteinPct": 0.0,
        "crudeFatPct": 0.0,
        "crudeFiberPct": 0.0,
        "calciumPct": 0.0,
        "phosphorusPct": 0.0,
        "metabolicEnergyKcal": 2800.0  # Default baseline energy
    }

    # Regex patterns for Guaranteed Analysis fields
    patterns = {
        "crudeProteinPct": r"(?:Crude\s+Protein|Protein)[^\d%]*(\d+(?:\.\d+)?)%",
        "crudeFatPct": r"(?:Crude\s+Fat|Fat)[^\d%]*(\d+(?:\.\d+)?)%",
        "crudeFiberPct": r"(?:Crude\s+Fiber|Fiber)[^\d%]*(\d+(?:\.\d+)?)%",
        "calciumPct": r"(?:Calcium|Ca)[^\d%]*(\d+(?:\.\d+)?)%",
        "phosphorusPct": r"(?:Phosphorus|Phos|P)[^\d%]*(\d+(?:\.\d+)?)%",
        "moisturePct": r"(?:Moisture)[^\d%]*(\d+(?:\.\d+)?)%",
    }

    for metric, pattern in patterns.items():
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                metrics[metric] = float(match.group(1))
            except ValueError:
                pass

    return metrics


# -------------------------------------------------------------------
# 1. Scrape / Query Open Pet Food Facts API (Commercial Kibble/Feeds)
# -------------------------------------------------------------------
def fetch_open_pet_food_facts(queries=["dog food", "cat food", "bird food", "reptile"]):
    print("🌐 Querying Open Pet Food Facts Database...")
    scraped_kibble = []

    for query in queries:
        url = f"https://world.openpetfoodfacts.org/cgi/search.pl?search_terms={query}&search_simple=1&action=process&json=1&page_size=20"
        try:
            res = requests.get(url, headers={"User-Agent": "ForgeFeed/1.0"}, timeout=10)
            if res.status_code == 200:
                data = res.json()
                products = data.get("products", [])

                for p in products:
                    name = p.get("product_name")
                    if not name:
                        continue

                    brand = p.get("brands", "Generic")
                    nutriments = p.get("nutriments", {})

                    # Extract nutrition numbers if available
                    protein = float(nutriments.get("proteins_100g", 0.0))
                    fat = float(nutriments.get("fat_100g", 0.0))
                    fiber = float(nutriments.get("fiber_100g", 0.0))
                    calcium = float(nutriments.get("calcium_100g", 0.0))
                    phosphorus = float(nutriments.get("phosphorus_100g", 0.0))

                    # Sanitize product ID
                    clean_id = f"kibble_{re.sub(r'[^a-z0-9]', '_', name.lower())[:30]}"

                    item = {
                        "id": clean_id,
                        "name": name,
                        "brand": brand,
                        "catalogSource": "kibble",
                        "category": "Commercial Pet Feed",
                        "subCategory": query.capitalize(),
                        "description": p.get("ingredients_text", "Commercial processed animal feed diet."),
                        "asFedMetrics": {
                            "moisturePct": 10.0,
                            "crudeProteinPct": protein,
                            "crudeFatPct": fat,
                            "crudeFiberPct": fiber,
                            "calciumPct": calcium,
                            "phosphorusPct": phosphorus,
                            "metabolicEnergyKcal": 3200.0
                        },
                        "tags": [query, "kibble", brand.lower()]
                    }
                    scraped_kibble.append(item)
        except Exception as e:
            print(f"  ⚠️ Error scraping Open Pet Food Facts for query '{query}': {e}")

    return scraped_kibble


# -------------------------------------------------------------------
# 2. Universal Webpage Guaranteed Analysis Extractor
# -------------------------------------------------------------------
def scrape_custom_feed_url(url, brand_name, product_name, category, sub_category):
    print(f"🔎 Scraping: {product_name} ({brand_name})...")
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, "html.parser")
            text = soup.get_text()
            
            # Extract guaranteed analysis metrics from page text
            metrics = parse_guaranteed_analysis(text)
            clean_id = f"feed_{re.sub(r'[^a-z0-9]', '_', product_name.lower())[:30]}"

            return {
                "id": clean_id,
                "name": product_name,
                "brand": brand_name,
                "catalogSource": "livestock",
                "category": category,
                "subCategory": sub_category,
                "description": f"Scraped catalog entry for {product_name} from {brand_name}.",
                "asFedMetrics": metrics,
                "tags": [category.lower(), sub_category.lower(), brand_name.lower()]
            }
    except Exception as e:
        print(f"  ⚠️ Failed to scrape {url}: {e}")
    
    return None


# -------------------------------------------------------------------
# Main Pipeline Runner
# -------------------------------------------------------------------
def main():
    print("🚀 Starting ForgeFeed Automated Data Scraper...")

    # 1. Fetch from Open Pet Food Facts API
    api_kibble_items = fetch_open_pet_food_facts()

    # Read existing pet_kibble.json to merge without duplicates
    kibble_file_path = os.path.join(OUTPUT_DIR, "pet_kibble.json")
    existing_kibble = []
    if os.path.exists(kibble_file_path):
        with open(kibble_file_path, "r") as f:
            existing_kibble = json.load(f)

    # Deduplicate by ID
    kibble_map = {item["id"]: item for item in existing_kibble}
    for item in api_kibble_items:
        kibble_map[item["id"]] = item

    final_kibble_list = list(kibble_map.values())

    # Write merged pet kibble catalog
    with open(kibble_file_path, "w") as f:
        json.dump(final_kibble_list, f, indent=2)

    print(f"🎉 Updated {kibble_file_path} (Total items: {len(final_kibble_list)})")


if __name__ == "__main__":
    main()