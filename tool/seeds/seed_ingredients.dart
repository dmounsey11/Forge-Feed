/// Seed data for master feed ingredients database.

List<Map<String, dynamic>> getIngredientData() {
  return [
    {
      "id": "yellow_corn",
      "name": "Yellow Corn (Ground)",
      "category": "Grains & Energy",
      "crude_protein": 8.5,
      "crude_fat": 3.8,
      "crude_fiber": 2.2,
      "calcium": 0.02,
      "phosphorus": 0.28,
      "lysine": 0.24,
      "methionine": 0.18,
      "me_kcal_kg": 3350
    },
    {
      "id": "soybean_meal_48",
      "name": "Soybean Meal (48% CP)",
      "category": "Proteins",
      "crude_protein": 48.0,
      "crude_fat": 1.0,
      "crude_fiber": 3.5,
      "calcium": 0.20,
      "phosphorus": 0.65,
      "lysine": 3.0,
      "methionine": 0.68,
      "me_kcal_kg": 2440
    },
    {
      "id": "alfalfa_meal",
      "name": "Alfalfa Meal (Dehydrated)",
      "category": "Forages",
      "crude_protein": 17.0,
      "crude_fat": 2.5,
      "crude_fiber": 25.0,
      "calcium": 1.30,
      "phosphorus": 0.22,
      "lysine": 0.72,
      "methionine": 0.24,
      "me_kcal_kg": 1850
    },
    {
      "id": "calcium_carbonate",
      "name": "Feed Grade Limestone (Calcium Carbonate)",
      "category": "Minerals",
      "crude_protein": 0.0,
      "crude_fat": 0.0,
      "crude_fiber": 0.0,
      "calcium": 38.0,
      "phosphorus": 0.0,
      "lysine": 0.0,
      "methionine": 0.0,
      "me_kcal_kg": 0
    },
    {
      "id": "monocalcium_phosphate",
      "name": "Monocalcium Phosphate",
      "category": "Minerals",
      "crude_protein": 0.0,
      "crude_fat": 0.0,
      "crude_fiber": 0.0,
      "calcium": 16.0,
      "phosphorus": 21.0,
      "lysine": 0.0,
      "methionine": 0.0,
      "me_kcal_kg": 0
    }
  ];
}