import json
import os

# Ensure assets/data directory exists
output_dir = os.path.join("assets", "data")
os.makedirs(output_dir, exist_ok=True)

# 1. Commercial Livestock Feeds Catalog
livestock_feeds = [
    {
        "id": "feed_purina_layena_pellets",
        "name": "Purina Layena SunFresh Recipe Pellets",
        "brand": "Purina",
        "catalogSource": "livestock",
        "category": "Poultry Feed",
        "subCategory": "Layer",
        "description": "16% crude protein complete feed for laying hens.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 16.0,
            "crudeFatPct": 2.5,
            "crudeFiberPct": 7.0,
            "calciumPct": 3.8,
            "phosphorusPct": 0.45,
            "metabolicEnergyKcal": 2800.0
        },
        "tags": ["chicken", "layer", "poultry", "purina"]
    },
    {
        "id": "feed_nutrena_country_feeds_16",
        "name": "Nutrena Country Feeds 16% Layer",
        "brand": "Nutrena",
        "catalogSource": "livestock",
        "category": "Poultry Feed",
        "subCategory": "Layer",
        "description": "Balanced nutrition for laying chickens.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 16.0,
            "crudeFatPct": 2.5,
            "crudeFiberPct": 6.5,
            "calciumPct": 3.8,
            "phosphorusPct": 0.5,
            "metabolicEnergyKcal": 2850.0
        },
        "tags": ["chicken", "layer", "poultry", "nutrena"]
    },
    {
        "id": "feed_purina_gamebird_30_starter",
        "name": "Purina Game Bird & Turkey Starter",
        "brand": "Purina",
        "catalogSource": "livestock",
        "category": "Game Bird & Avian",
        "subCategory": "Starter",
        "description": "High-protein starter crumbs for quail, turkey poults, and game birds.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 30.0,
            "crudeFatPct": 3.0,
            "crudeFiberPct": 5.0,
            "calciumPct": 1.2,
            "phosphorusPct": 0.8,
            "metabolicEnergyKcal": 2900.0
        },
        "tags": ["quail", "turkey", "gamebird", "starter"]
    },
    {
        "id": "feed_manna_pro_goat_20",
        "name": "Manna Pro Goat Balancer 20%",
        "brand": "Manna Pro",
        "catalogSource": "livestock",
        "category": "Goat & Sheep",
        "subCategory": "Balancer",
        "description": "Protein supplement formulated for all classes of goats.",
        "asFedMetrics": {
            "moisturePct": 10.0,
            "crudeProteinPct": 20.0,
            "crudeFatPct": 4.0,
            "crudeFiberPct": 10.0,
            "calciumPct": 1.8,
            "phosphorusPct": 0.8,
            "metabolicEnergyKcal": 2950.0
        },
        "tags": ["goat", "balancer", "manna pro"]
    }
]

# 2. Commercial Kibble & Exotic Pet Feeds Catalog
pet_kibble = [
    {
        "id": "kibble_mazuri_exotic_gamebird_maint",
        "name": "Mazuri Exotic Gamebird Maintenance",
        "brand": "Mazuri",
        "catalogSource": "kibble",
        "category": "Exotic & Specialized",
        "subCategory": "Avian",
        "description": "Extruded diet formulated for non-breeding adult exotic birds.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 20.0,
            "crudeFatPct": 4.5,
            "crudeFiberPct": 6.0,
            "calciumPct": 1.15,
            "phosphorusPct": 0.75,
            "metabolicEnergyKcal": 3000.0
        },
        "tags": ["exotic", "gamebird", "mazuri", "pellets"]
    },
    {
        "id": "kibble_repashy_calcium_plus",
        "name": "Repashy Calcium Plus Powder",
        "brand": "Repashy",
        "catalogSource": "kibble",
        "category": "Reptile & Amphibian",
        "subCategory": "Supplement",
        "description": "All-in-one insect dusting powder with calcium and essential vitamins.",
        "asFedMetrics": {
            "moisturePct": 6.0,
            "crudeProteinPct": 0.0,
            "crudeFatPct": 0.0,
            "crudeFiberPct": 0.0,
            "calciumPct": 20.0,
            "phosphorusPct": 0.0,
            "metabolicEnergyKcal": 0.0
        },
        "tags": ["reptile", "dusting", "calcium", "supplement"]
    },
    {
        "id": "kibble_mazuri_insectivore_diet",
        "name": "Mazuri Insectivore Diet",
        "brand": "Mazuri",
        "catalogSource": "kibble",
        "category": "Exotic & Specialized",
        "subCategory": "Mammals",
        "description": "Simulates high-protein insect-based diets for hedgehogs and exotic mammals.",
        "asFedMetrics": {
            "moisturePct": 10.0,
            "crudeProteinPct": 28.0,
            "crudeFatPct": 11.0,
            "crudeFiberPct": 13.0,
            "calciumPct": 1.2,
            "phosphorusPct": 0.9,
            "metabolicEnergyKcal": 3200.0
        },
        "tags": ["exotic", "insectivore", "mazuri", "hedgehog"]
    }
]

# Write files to assets/data/
livestock_path = os.path.join(output_dir, "livestock_feeds.json")
kibble_path = os.path.join(output_dir, "pet_kibble.json")

with open(livestock_path, "w") as f:
    json.dump(livestock_feeds, f, indent=2)

with open(kibble_path, "w") as f:
    json.dump(pet_kibble, f, indent=2)

print(f"✅ Generated {livestock_path} ({len(livestock_feeds)} items)")
print(f"✅ Generated {kibble_path} ({len(pet_kibble)} items)")