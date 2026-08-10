/// Seed data for Poultry & Waterfowl life stages.

Map<String, dynamic> getPoultryData() {
  return {
    "chicken_layers": {
      "display_name": "Chickens (Layers)",
      "stages": {
        "chick_starter": {
          "name": "Chick Starter (0-6 wks)",
          "crude_protein_min": 20.0,
          "me_kcal_kg": 2850,
          "calcium_min": 1.0,
          "phosphorus_min": 0.45,
          "lysine_min": 1.0,
          "methionine_min": 0.45
        },
        "pullet_developer": {
          "name": "Pullet Developer (6-18 wks)",
          "crude_protein_min": 16.0,
          "me_kcal_kg": 2800,
          "calcium_min": 0.9,
          "phosphorus_min": 0.40,
          "lysine_min": 0.75,
          "methionine_min": 0.35
        },
        "layer_peak": {
          "name": "Layer (Peak Production)",
          "crude_protein_min": 17.0,
          "me_kcal_kg": 2800,
          "calcium_min": 4.0,
          "phosphorus_min": 0.45,
          "lysine_min": 0.85,
          "methionine_min": 0.42
        }
      }
    },
    "chicken_broilers": {
      "display_name": "Chickens (Broilers)",
      "stages": {
        "broiler_starter": {
          "name": "Broiler Starter (0-3 wks)",
          "crude_protein_min": 22.0,
          "me_kcal_kg": 3000,
          "calcium_min": 0.95,
          "phosphorus_min": 0.45,
          "lysine_min": 1.2,
          "methionine_min": 0.50
        },
        "broiler_grower": {
          "name": "Broiler Grower (3-6 wks)",
          "crude_protein_min": 20.0,
          "me_kcal_kg": 3100,
          "calcium_min": 0.85,
          "phosphorus_min": 0.42,
          "lysine_min": 1.1,
          "methionine_min": 0.45
        }
      }
    },
    "turkeys": {
      "display_name": "Turkeys",
      "stages": {
        "poult_starter": {
          "name": "Poult Starter (0-4 wks)",
          "crude_protein_min": 28.0,
          "me_kcal_kg": 2900,
          "calcium_min": 1.2,
          "phosphorus_min": 0.60,
          "lysine_min": 1.6,
          "methionine_min": 0.55
        }
      }
    },
    "waterfowl": {
      "display_name": "Ducks & Geese",
      "stages": {
        "duckling_starter": {
          "name": "Duckling/Gosling Starter (0-3 wks)",
          "crude_protein_min": 20.0,
          "me_kcal_kg": 2900,
          "calcium_min": 0.9,
          "phosphorus_min": 0.45,
          "lysine_min": 1.0,
          "methionine_min": 0.40
        }
      }
    }
  };
}