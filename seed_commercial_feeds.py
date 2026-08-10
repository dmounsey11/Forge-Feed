import json
import os

# Ensure assets/data directory exists
output_dir = os.path.join("assets", "data")
os.makedirs(output_dir, exist_ok=True)

# ---------------------------------------------------------
# 1. USDA Whole Foods & Raw Staples (usda_ingredients.json)
# ---------------------------------------------------------
usda_ingredients = [
    {
        "id": "usda_yellow_dent_corn",
        "name": "USDA Yellow Dent Corn, Grain, Raw",
        "brand": "USDA Standard",
        "catalogSource": "usda",
        "category": "Grains & Cereals",
        "subCategory": "Energy Feed",
        "description": "Standard feed energy benchmark, high in TDN and metabolic energy.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 8.5,
            "crudeFatPct": 3.8,
            "crudeFiberPct": 2.2,
            "calciumPct": 0.02,
            "phosphorusPct": 0.28,
            "metabolicEnergyKcal": 3350.0
        },
        "tags": ["grain", "corn", "energy", "raw", "usda"]
    },
    {
        "id": "usda_soybean_meal_48",
        "name": "Soybean Meal (48% Solvent Extracted)",
        "brand": "USDA Standard",
        "catalogSource": "usda",
        "category": "Protein Meal",
        "subCategory": "Oilseed Meal",
        "description": "High-protein plant meal rich in lysine and essential amino acids.",
        "asFedMetrics": {
            "moisturePct": 10.0,
            "crudeProteinPct": 47.5,
            "crudeFatPct": 1.0,
            "crudeFiberPct": 3.5,
            "calciumPct": 0.27,
            "phosphorusPct": 0.65,
            "metabolicEnergyKcal": 2230.0
        },
        "tags": ["soy", "protein", "meal", "amino acids", "usda"]
    },
    {
        "id": "usda_whole_oats",
        "name": "Whole Grain Oats",
        "brand": "USDA Standard",
        "catalogSource": "usda",
        "category": "Grains & Cereals",
        "subCategory": "High Fiber Grain",
        "description": "Fibrous cereal grain beneficial for gizzard development and scratch feeds.",
        "asFedMetrics": {
            "moisturePct": 11.0,
            "crudeProteinPct": 11.5,
            "crudeFatPct": 4.8,
            "crudeFiberPct": 10.5,
            "calciumPct": 0.09,
            "phosphorusPct": 0.33,
            "metabolicEnergyKcal": 2550.0
        },
        "tags": ["oats", "grain", "fiber", "scratch", "usda"]
    },
    {
        "id": "usda_black_soldier_fly_larvae",
        "name": "Dried Black Soldier Fly Larvae (BSFL)",
        "brand": "USDA Standard",
        "catalogSource": "usda",
        "category": "Insects & Larvae",
        "subCategory": "High Calcium Protein",
        "description": "Whole insect feed packed with high protein and balanced natural calcium.",
        "asFedMetrics": {
            "moisturePct": 5.0,
            "crudeProteinPct": 40.0,
            "crudeFatPct": 32.0,
            "crudeFiberPct": 7.0,
            "calciumPct": 2.4,
            "phosphorusPct": 0.9,
            "metabolicEnergyKcal": 2900.0
        },
        "tags": ["bsfl", "insects", "grubs", "calcium", "treat"]
    },
    {
        "id": "usda_black_oil_sunflower_seeds",
        "name": "Black Oil Sunflower Seeds (BOSS)",
        "brand": "USDA Standard",
        "catalogSource": "usda",
        "category": "Seeds & Nuts",
        "subCategory": "High Fat Seed",
        "description": "High-fat oilseed favored for feather condition, molt recovery, and winter energy.",
        "asFedMetrics": {
            "moisturePct": 8.0,
            "crudeProteinPct": 16.0,
            "crudeFatPct": 40.0,
            "crudeFiberPct": 21.0,
            "calciumPct": 0.2,
            "phosphorusPct": 0.6,
            "metabolicEnergyKcal": 3700.0
        },
        "tags": ["boss", "sunflower", "seeds", "fat", "molt"]
    },
    {
        "id": "usda_alfalfa_meal_pellets",
        "name": "Dehydrated Alfalfa Meal Pellets (17%)",
        "brand": "USDA Standard",
        "catalogSource": "usda",
        "category": "Forage & Hay",
        "subCategory": "Legume Forage",
        "description": "Rich legume forage supplying fiber, natural carotene for yolk color, and calcium.",
        "asFedMetrics": {
            "moisturePct": 9.0,
            "crudeProteinPct": 17.0,
            "crudeFatPct": 2.5,
            "crudeFiberPct": 25.0,
            "calciumPct": 1.4,
            "phosphorusPct": 0.25,
            "metabolicEnergyKcal": 1950.0
        },
        "tags": ["alfalfa", "forage", "hay", "yolk", "fiber"]
    }
]

# ---------------------------------------------------------
# 2. Commercial Livestock Feeds (livestock_feeds.json)
# ---------------------------------------------------------
livestock_feeds = [
    # POULTRY - LAYERS & CHICKENS
    {
        "id": "feed_purina_layena_pellets",
        "name": "Purina Layena SunFresh Recipe Pellets",
        "brand": "Purina",
        "catalogSource": "livestock",
        "category": "Poultry Feed",
        "subCategory": "Layer",
        "description": "16% crude protein complete feed formulated for laying hens with calcium.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 16.0,
            "crudeFatPct": 2.5,
            "crudeFiberPct": 7.0,
            "calciumPct": 3.8,
            "phosphorusPct": 0.45,
            "metabolicEnergyKcal": 2800.0
        },
        "tags": ["chicken", "layer", "poultry", "purina", "pellets"]
    },
    {
        "id": "feed_nutrena_country_feeds_16",
        "name": "Nutrena Country Feeds 16% Layer Crumbles",
        "brand": "Nutrena",
        "catalogSource": "livestock",
        "category": "Poultry Feed",
        "subCategory": "Layer",
        "description": "Balanced daily maintenance and egg production ration for backyard layers.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 16.0,
            "crudeFatPct": 2.5,
            "crudeFiberPct": 6.5,
            "calciumPct": 3.8,
            "phosphorusPct": 0.5,
            "metabolicEnergyKcal": 2850.0
        },
        "tags": ["chicken", "layer", "poultry", "nutrena", "crumbles"]
    },
    {
        "id": "feed_scratch_and_peck_layer_16",
        "name": "Scratch and Peck Naturally Free Organic Layer 16%",
        "brand": "Scratch & Peck",
        "catalogSource": "livestock",
        "category": "Poultry Feed",
        "subCategory": "Organic Layer",
        "description": "Whole grain, non-GMO soy-free and corn-free layer ration.",
        "asFedMetrics": {
            "moisturePct": 11.0,
            "crudeProteinPct": 16.0,
            "crudeFatPct": 3.5,
            "crudeFiberPct": 5.0,
            "calciumPct": 3.5,
            "phosphorusPct": 0.4,
            "metabolicEnergyKcal": 2900.0
        },
        "tags": ["organic", "chicken", "layer", "soy-free", "whole grain"]
    },

    # GAMEBIRD, QUAIL & TURKEY
    {
        "id": "feed_purina_gamebird_30_starter",
        "name": "Purina Game Bird & Turkey Starter (30%)",
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
        "tags": ["quail", "turkey", "gamebird", "starter", "purina"]
    },
    {
        "id": "feed_purina_gamebird_flight_conditioner",
        "name": "Purina Game Bird Flight Conditioner (19%)",
        "brand": "Purina",
        "catalogSource": "livestock",
        "category": "Game Bird & Avian",
        "subCategory": "Grower / Maintenance",
        "description": "Complete grow-out diet for flight birds, quail, and pheasant.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 19.0,
            "crudeFatPct": 3.0,
            "crudeFiberPct": 5.0,
            "calciumPct": 0.9,
            "phosphorusPct": 0.7,
            "metabolicEnergyKcal": 2820.0
        },
        "tags": ["quail", "pheasant", "gamebird", "purina", "grower"]
    },

    # SWINE / PIGS
    {
        "id": "feed_purina_nature_wise_swine_16",
        "name": "Purina Country Acres Hog Grower 16%",
        "brand": "Purina",
        "catalogSource": "livestock",
        "category": "Swine",
        "subCategory": "Grower & Finisher",
        "description": "Complete growing and finishing ration for heritage and farm pigs.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 16.0,
            "crudeFatPct": 3.0,
            "crudeFiberPct": 5.5,
            "calciumPct": 0.7,
            "phosphorusPct": 0.6,
            "metabolicEnergyKcal": 3200.0
        },
        "tags": ["swine", "pigs", "grower", "purina", "hog"]
    },

    # RUMINANTS & SMALL RUMINANTS (GOATS/SHEEP)
    {
        "id": "feed_manna_pro_goat_balancer_20",
        "name": "Manna Pro Goat Balancer 20%",
        "brand": "Manna Pro",
        "catalogSource": "livestock",
        "category": "Goat & Sheep",
        "subCategory": "Balancer / Supplement",
        "description": "Protein and mineral supplement formulated for all classes of goats.",
        "asFedMetrics": {
            "moisturePct": 10.0,
            "crudeProteinPct": 20.0,
            "crudeFatPct": 4.0,
            "crudeFiberPct": 10.0,
            "calciumPct": 1.8,
            "phosphorusPct": 0.8,
            "metabolicEnergyKcal": 2950.0
        },
        "tags": ["goat", "balancer", "manna pro", "ruminant"]
    }
]

# ---------------------------------------------------------
# 3. Commercial Kibble & Exotic Pet Feeds (pet_kibble.json)
# ---------------------------------------------------------
pet_kibble = [
    {
        "id": "kibble_mazuri_exotic_gamebird_maint",
        "name": "Mazuri Exotic Gamebird Maintenance",
        "brand": "Mazuri",
        "catalogSource": "kibble",
        "category": "Exotic & Specialized",
        "subCategory": "Avian",
        "description": "Extruded diet formulated for non-breeding adult exotic birds and wildfowl.",
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
        "id": "kibble_mazuri_insectivore_diet",
        "name": "Mazuri Insectivore Diet",
        "brand": "Mazuri",
        "catalogSource": "kibble",
        "category": "Exotic & Specialized",
        "subCategory": "Mammals",
        "description": "Simulates high-protein insect diets for hedgehogs, sugar gliders, and exotic insectivores.",
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
    },
    {
        "id": "kibble_repashy_calcium_plus",
        "name": "Repashy Calcium Plus Powder",
        "brand": "Repashy",
        "catalogSource": "kibble",
        "category": "Reptile & Amphibian",
        "subCategory": "Supplement Powder",
        "description": "All-in-one dusting powder with bioavailable calcium and essential vitamins.",
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
        "id": "kibble_mazuri_tortoise_diet",
        "name": "Mazuri Tortoise Diet 5M21",
        "brand": "Mazuri",
        "catalogSource": "kibble",
        "category": "Reptile & Amphibian",
        "subCategory": "Chelonian",
        "description": "High-fiber diet designed for dry-land herbivorous tortoises.",
        "asFedMetrics": {
            "moisturePct": 12.0,
            "crudeProteinPct": 15.0,
            "crudeFatPct": 3.0,
            "crudeFiberPct": 18.0,
            "calciumPct": 1.1,
            "phosphorusPct": 0.6,
            "metabolicEnergyKcal": 2400.0
        },
        "tags": ["tortoise", "reptile", "mazuri", "high-fiber"]
    }
]

# Write files to assets/data/
usda_path = os.path.join(output_dir, "usda_ingredients.json")
livestock_path = os.path.join(output_dir, "livestock_feeds.json")
kibble_path = os.path.join(output_dir, "pet_kibble.json")

with open(usda_path, "w") as f:
    json.dump(usda_ingredients, f, indent=2)

with open(livestock_path, "w") as f:
    json.dump(livestock_feeds, f, indent=2)

with open(kibble_path, "w") as f:
    json.dump(pet_kibble, f, indent=2)

print(f"✅ Generated {usda_path} ({len(usda_ingredients)} items)")
print(f"✅ Generated {livestock_path} ({len(livestock_feeds)} items)")
print(f"✅ Generated {kibble_path} ({len(pet_kibble)} items)")