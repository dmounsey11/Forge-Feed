import requests
import json
import os
import re
import urllib3
from bs4 import BeautifulSoup

# Suppress SSL verification warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

OUTPUT_FILE = os.path.join("assets", "data", "aza_nag_clinical_notes.json")
NAG_URL = "https://nagonline.net/category/information/"

def scrape_aza_publications():
    print("Scraping AZA Nutrition Advisory Group Public Library...")
    headers = {"User-Agent": "ForgeFeedNutritionalBot/1.0"}
    
    records = []
    try:
        # verify=False bypasses SSL certificate verification errors
        response = requests.get(NAG_URL, headers=headers, timeout=15, verify=False)
        soup = BeautifulSoup(response.text, "html.parser")
        
        articles = soup.find_all("article")
        for art in articles:
            title_elem = art.find(["h1", "h2", "h3"])
            snippet_elem = art.find("div", class_="entry-content") or art.find("p")
            
            if title_elem:
                title = title_elem.get_text(strip=True)
                snippet = snippet_elem.get_text(strip=True) if snippet_elem else ""
                
                records.append({
                    "title": title,
                    "summary": snippet[:300] + "..." if len(snippet) > 300 else snippet,
                    "source": "AZA Nutrition Advisory Group (nagonline.net)"
                })
                
        print(f"Retrieved {len(records)} AZA NAG publication references.")
    except Exception as e:
        print(f"Error scraping AZA NAG: {e}")

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(records, f, indent=2)
        
    print(f"Saved AZA NAG notes to: {OUTPUT_FILE}")

if __name__ == "__main__":
    scrape_aza_publications()