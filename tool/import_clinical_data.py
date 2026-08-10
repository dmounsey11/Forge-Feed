import csv
import json
import os
import re

# Output path matching ForgeFeed asset pipeline
OUTPUT_JSON_PATH = os.path.join("assets", "scraped_exotics_seed.json")

def sanitize_id(name: str) -> str:
    """Generates a clean snake_case ID matching ForgeFeed conventions."""
    clean_str = re.sub(r'[^a-zA-Z0-9\s_]', '', name.lower())
    return f"spec_{clean_str.replace(' ', '_')}"

def build_requirement_record(
    name: str,
    category: str,
    description: str,
    crude_protein: float,
    crude_fat: float,
    crude_fiber: float,
    calcium: float,
    phosphorus: float,
    ca_to_p_ratio: str = "2:1",
    vitamin_d3: float = 0.0,
    vet_source: str = "VetLexicon / Clinical Reference"
) -> dict:
    """
    Constructs a normalized species dictionary matching ForgeFeed's exact schema.
    Note: Cost and financial parameters are strictly excluded.
    """
    return {
        "id": sanitize_id(name),
        "name": name.strip(),
        "category": category.strip() if category else "Exotics",
        "description": description.strip() if description else "",
        "veterinarySource": vet_source.strip() if vet_source else "Clinical Reference",
        "caToPRatio": ca_to_p_ratio.strip() if ca_to_p_ratio else "2:1",
        "vitaminD3IU": float(vitamin_d3) if vitamin_d3 else 0.0,
        "requirements": {
            "crudeProtein": float(crude_protein) if crude_protein else 0.0,
            "crudeFat": float(crude_fat) if crude_fat else 0.0,
            "crudeFiber": float(crude_fiber) if crude_fiber else 0.0,
            "calcium": float(calcium) if calcium else 0.0,
            "phosphorus": float(phosphorus) if phosphorus else 0.0
        }
    }

def import_from_csv(csv_filepath: str) -> list:
    """
    Parses a CSV file containing clinical species requirements.
    Expected CSV headers:
    name,category,description,crudeProtein,crudeFat,crudeFiber,calcium,phosphorus,caToPRatio,vitaminD3IU,vetSource
    """
    records = []
    if not os.path.exists(csv_filepath):
        print(f"File not found: {csv_filepath}")
        return records

    with open(csv_filepath, mode='r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            record = build_requirement_record(
                name=row.get("name", "Unknown Species"),
                category=row.get("category", "Exotics"),
                description=row.get("description", ""),
                crude_protein=row.get("crudeProtein", 0.0),
                crude_fat=row.get("crudeFat", 0.0),
                crude_fiber=row.get("crudeFiber", 0.0),
                calcium=row.get("calcium", 0.0),
                phosphorus=row.get("phosphorus", 0.0),
                ca_to_p_ratio=row.get("caToPRatio", "2:1"),
                vitamin_d3=row.get("vitaminD3IU", 0.0),
                vet_source=row.get("vetSource", "VetLexicon Clinical Record")
            )
            records.append(record)
    return records

def save_to_assets(records: list):
    """Saves compiled records directly to assets/scraped_exotics_seed.json."""
    os.makedirs(os.path.dirname(OUTPUT_JSON_PATH), exist_ok=True)
    with open(OUTPUT_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(records, f, indent=2)
    print(f"Successfully wrote {len(records)} species records to {OUTPUT_JSON_PATH}")

if __name__ == "__main__":
    # Ingests root master CSV file
    input_csv = "master_animal_requirements.csv"
    
    print(f"Importing clinical requirements from {input_csv}...")
    imported_records = import_from_csv(input_csv)
    
    if imported_records:
        save_to_assets(imported_records)
    else:
        print("No records imported. Please verify master_animal_requirements.csv exists.")