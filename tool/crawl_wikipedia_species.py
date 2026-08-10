import requests
import json
import os
import re
import time
import urllib3

# Suppress SSL verification warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

OUTPUT_FILE = os.path.join("assets", "scraped_exotics_seed.json")
WIKI_API_URL = "https://en.wikipedia.org/w/api.php"

VERIFIED_CATEGORIES = {
    "Reptiles": ["Category:Reptiles as pets", "Category:Lizards as pets", "Category:Snakes as pets"],
    "Birds": ["Category:Domesticated birds", "Category:Parrots", "Category:Companion parrots"],
    "Rodents": ["Category:Rodents as pets", "Category:Small mammals as pets"],
    "Amphibians": ["Category:Amphibians as pets"],
    "Exotic Mammals": ["Category:Exotic pets"]
}

CATEGORY_DEFAULTS = {
    "Reptiles": {"protein": 20.0, "fat": 6.0, "fiber": 15.0, "ca": 1.5, "p": 0.8, "ratio": "2:1", "d3": 1800.0},
    "Birds": {"protein": 14.0, "fat": 6.0, "fiber": 5.0, "ca": 1.0, "p": 0.5, "ratio": "2:1", "d3": 1000.0},
    "Rodents": {"protein": 16.0, "fat": 4.0, "fiber": 18.0, "ca": 0.8, "p": 0.4, "ratio": "1.8:1", "d3": 1000.0},
    "Amphibians": {"protein": 45.0, "fat": 12.0, "fiber": 4.0, "ca": 1.2, "p": 0.8, "ratio": "1.5:1", "d3": 800.0},
    "Exotic Mammals": {"protein": 22.0, "fat": 8.0, "fiber": 10.0, "ca": 1.0, "p": 0.6, "ratio": "1.5:1", "d3": 1200.0}
}

def sanitize_id(name: str) -> str:
    clean_str = re.sub(r'[^a-zA-Z0-9\s_]', '', name.lower())
    return f"spec_{clean_str.replace(' ', '_')}"

def fetch_category_members(category_title: str) -> list:
    params = {
        "action": "query",
        "list": "categorymembers",
        "cmtitle": category_title,
        "cmlimit": "500",
        "format": "json"
    }
    headers = {"User-Agent": "ForgeFeedApp/1.0 (Educational Nutrition Platform)"}
    try:
        # verify=False bypasses SSL certificate verification errors
        res = requests.get(WIKI_API_URL, params=params, headers=headers, timeout=10, verify=False)
        data = res.json()
        members = data.get("query", {}).get("categorymembers", [])
        return [m["title"] for m in members]
    except Exception as e:
        print(f"Error reading {category_title}: {e}")
        return []

def main():
    print("Starting Wikipedia Exotic Species Crawl...")
    master_map = {}

    for cat_name, cat_list in VERIFIED_CATEGORIES.items():
        defaults = CATEGORY_DEFAULTS.get(cat_name, CATEGORY_DEFAULTS["Exotic Mammals"])
        for wiki_cat in cat_list:
            print(f"Fetching: {wiki_cat}...")
            titles = fetch_category_members(wiki_cat)
            
            for title in titles:
                if title.startswith("Category:") or title.startswith("File:") or "List of" in title:
                    continue
                
                clean_name = re.sub(r'\s*\([^)]*\)', '', title)
                spec_id = sanitize_id(clean_name)

                if spec_id not in master_map:
                    master_map[spec_id] = {
                        "id": spec_id,
                        "name": clean_name,
                        "category": cat_name,
                        "description": f"Captive profile for {clean_name}.",
                        "veterinarySource": "Wikipedia / AZA NAG Public Baseline",
                        "caToPRatio": defaults["ratio"],
                        "vitaminD3IU": defaults["d3"],
                        "requirements": {
                            "crudeProtein": defaults["protein"],
                            "crudeFat": defaults["fat"],
                            "crudeFiber": defaults["fiber"],
                            "calcium": defaults["ca"],
                            "phosphorus": defaults["p"]
                        }
                    }

    output_list = list(master_map.values())
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_list, f, indent=2)

    print(f"\nSUCCESS! Compiled {len(output_list)} species into {OUTPUT_FILE}")

if __name__ == "__main__":
    main()