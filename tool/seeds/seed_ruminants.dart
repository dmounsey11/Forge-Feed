/// Seed data for Goats, Sheep, and Cattle life stages.

Map<String, dynamic> getRuminantData() {
  return {
    "dairy_goats": {
      "display_name": "Dairy Goats",
      "stages": {
        "lactating_doe": {
          "name": "Lactating Doe (Peak)",
          "crude_protein_min": 16.0,
          "calcium_min": 0.8,
          "phosphorus_min": 0.5,
          "fiber_max": 20.0
        },
        "dry_doe": {
          "name": "Dry Doe / Maintenance",
          "crude_protein_min": 10.0,
          "calcium_min": 0.4,
          "phosphorus_min": 0.25,
          "fiber_max": 30.0
        }
      }
    },
    "meat_goats": {
      "display_name": "Meat Goats",
      "stages": {
        "growing_kid": {
          "name": "Growing Kid",
          "crude_protein_min": 14.0,
          "calcium_min": 0.6,
          "phosphorus_min": 0.35,
          "fiber_max": 22.0
        }
      }
    },
    "sheep": {
      "display_name": "Sheep",
      "stages": {
        "lactating_ewe": {
          "name": "Lactating Ewe",
          "crude_protein_min": 15.0,
          "calcium_min": 0.6,
          "phosphorus_min": 0.35,
          "copper_max_ppm": 15.0
        }
      }
    }
  };
}