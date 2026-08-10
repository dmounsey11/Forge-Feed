import json
import re
import requests
from bs4 import BeautifulSoup
import urllib3

# Suppress SSL verification warnings for local scraping
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
}

CATEGORIES = {
    # Poultry & Waterfowl
    "Chickens": "https://en.wikipedia.org/wiki/Category:Chicken_breeds",
    "Ducks": "https://en.wikipedia.org/wiki/Category:Duck_breeds",
    "Geese": "https://en.wikipedia.org/wiki/Category:Goose_breeds",
    "Turkeys": "https://en.wikipedia.org/wiki/Category:Turkey_breeds",
    "Poultry (General)": "https://en.wikipedia.org/wiki/Category:Poultry",
    
    # Livestock & Ruminants
    "Goats": "https://en.wikipedia.org/wiki/Category:Goat_breeds",
    "Sheep": "https://en.wikipedia.org/wiki/Category:Sheep_breeds",
    "Cattle": "https://en.wikipedia.org/wiki/Category:Cattle_breeds",
    "Swine": "https://en.wikipedia.org/wiki/Category:Pig_breeds",
    "Equine": "https://en.wikipedia.org/wiki/Category:Horse_breeds",
    
    # Small Mammals & Pets
    "Rabbits": "https://en.wikipedia.org/wiki/Category:Rabbit_breeds",
    "Cats": "https://en.wikipedia.org/wiki/Category:Cat_breeds",
    "Dogs": "https://en.wikipedia.org/wiki/Category:Dog_breeds_originating_in_the_United_States",
}

def scrape_category_page(url, category_name):
    print(f"Scraping category [{category_name}] from {url}...")
    species_list = []
    
    try:
        # verify=False prevents SSL certificate check failures
        response = requests.get(url, headers=HEADERS, verify=False)
        if response.status_code != 200:
            print(f"Failed to fetch {url} (Status: {response.status_code})")
            return species_list
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Wikipedia category pages group entries inside 'mw-category'
        category_div = soup.find('div', class_='mw-category')
        if category_div:
            links = category_div.find_all('a')
            for link in links:
                title = link.text.strip()
                href = link.get('href', '')
                
                # Exclude internal category navigation links
                if title and not title.startswith("Category:") and not title.startswith("List of"):
                    species_list.append({
                        "name": title,
                        "category": category_name,
                        "wiki_url": f"https://en.wikipedia.org{href}"
                    })
    except Exception as e:
        print(f"Error scraping {url}: {e}")
        
    return species_list

def main():
    all_species = []
    
    for category_name, url in CATEGORIES.items():
        extracted = scrape_category_page(url, category_name)
        all_species.extend(extracted)
        
    output_path = "scraped_species_seed.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(all_species, f, indent=2)
        
    print(f"\nScraping complete! Saved {len(all_species)} species records to {output_path}.")

if __name__ == "__main__":
    main()