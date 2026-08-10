/// Seed data for Canine (Dogs) and Feline (Cats) life stages and nutritional requirements.

Map<String, dynamic> getPetData() {
  return {
    "canine": {
      "display_name": "Canine (Dogs)",
      "stages": {
        "puppy_growth_lactation": {
          "name": "Puppy (Growth & Reproduction)",
          "crude_protein_min": 22.5,
          "crude_fat_min": 8.5,
          "calcium_min": 1.2,
          "phosphorus_min": 1.0,
          "ca_p_ratio_optimal": 1.2,
          "me_kcal_kg": 3800,
          "fiber_max": 5.0
        },
        "adult_maintenance": {
          "name": "Adult Maintenance (Standard)",
          "crude_protein_min": 18.0,
          "crude_fat_min": 5.5,
          "calcium_min": 0.6,
          "phosphorus_min": 0.5,
          "ca_p_ratio_optimal": 1.3,
          "me_kcal_kg": 3500,
          "fiber_max": 5.0
        },
        "adult_active_working": {
          "name": "Adult Active / Working / Performance",
          "crude_protein_min": 25.0,
          "crude_fat_min": 12.0,
          "calcium_min": 0.8,
          "phosphorus_min": 0.6,
          "ca_p_ratio_optimal": 1.3,
          "me_kcal_kg": 4000,
          "fiber_max": 4.0
        },
        "senior_light_activity": {
          "name": "Senior / Weight Control",
          "crude_protein_min": 18.0,
          "crude_fat_min": 5.0,
          "calcium_min": 0.6,
          "phosphorus_min": 0.5,
          "ca_p_ratio_optimal": 1.3,
          "me_kcal_kg": 3100,
          "fiber_max": 8.0
        }
      }
    },
    "feline": {
      "display_name": "Feline (Cats)",
      "stages": {
        "kitten_growth_gestation": {
          "name": "Kitten (Growth & Gestation)",
          "crude_protein_min": 30.0,
          "crude_fat_min": 9.0,
          "calcium_min": 1.0,
          "phosphorus_min": 0.8,
          "taurine_min": 0.20,
          "ca_p_ratio_optimal": 1.2,
          "me_kcal_kg": 4000,
          "fiber_max": 4.0
        },
        "adult_maintenance": {
          "name": "Adult Maintenance",
          "crude_protein_min": 26.0,
          "crude_fat_min": 9.0,
          "calcium_min": 0.6,
          "phosphorus_min": 0.5,
          "taurine_min": 0.10,
          "ca_p_ratio_optimal": 1.2,
          "me_kcal_kg": 3600,
          "fiber_max": 5.0
        },
        "active_high_energy": {
          "name": "Active / High Energy",
          "crude_protein_min": 32.0,
          "crude_fat_min": 14.0,
          "calcium_min": 0.8,
          "phosphorus_min": 0.6,
          "taurine_min": 0.15,
          "ca_p_ratio_optimal": 1.2,
          "me_kcal_kg": 4100,
          "fiber_max": 4.0
        }
      }
    }
  };
}