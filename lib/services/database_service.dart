import 'package:flutter/foundation.dart';
import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../models/species_requirement.dart';

class DatabaseService extends ChangeNotifier {
  DatabaseService();
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  final Set<String> _pantryIds = {};
  final Set<String> _supplementIds = {};
  final List<Ingredient> _ingredients = [];
  final List<SpeciesRequirement> _speciesRequirements = [];

  Future<void> initialize() async {
    if (_ingredients.isEmpty) {
      _seedInitialCatalog();
    }
    notifyListeners();
  }

  void _seedInitialCatalog() {
    _ingredients.addAll([
      // Feed Ingredients
      Ingredient(
        id: 'usda_corn',
        name: 'USDA Yellow Dent Corn, Grain, Raw',
        category: 'Grains & Cereals',
        proteinPct: 8.5,
        calciumPctValue: 0.02,
        phosphorusPctValue: 0.28,
        fatPctValue: 3.8,
        fiberPctValue: 2.2,
        energyMeKcalLb: 1550,
      ),
      Ingredient(
        id: 'usda_barley',
        name: 'USDA Barley, Grain, Pearl, Raw',
        category: 'Grains & Cereals',
        proteinPct: 12.48,
        calciumPctValue: 0.03,
        phosphorusPctValue: 0.26,
        fatPctValue: 2.3,
        fiberPctValue: 17.3,
        energyMeKcalLb: 1400,
      ),
      Ingredient(
        id: 'usda_soybean_meal',
        name: 'Soybean Meal 48%',
        category: 'Proteins & Meal',
        proteinPct: 48.0,
        calciumPctValue: 0.20,
        phosphorusPctValue: 0.65,
        fatPctValue: 1.0,
        fiberPctValue: 3.5,
        energyMeKcalLb: 1100,
      ),
      Ingredient(
        id: 'usda_black_soldier_fly',
        name: 'Black Soldier Fly Larvae Meal',
        category: 'Proteins & Meal',
        proteinPct: 40.0,
        calciumPctValue: 2.20,
        phosphorusPctValue: 0.90,
        fatPctValue: 28.0,
        fiberPctValue: 6.0,
        energyMeKcalLb: 1800,
      ),

      // Supplements & Additives
      Ingredient(
        id: 'supp_calcium_limestone',
        name: 'Feed Grade Limestone (38% Ca)',
        category: 'Vitamins & Minerals',
        proteinPct: 0.0,
        calciumPctValue: 38.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 0.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 0,
      ),
      Ingredient(
        id: 'supp_oyster_shell',
        name: 'Coarse Oyster Shell Flakes',
        category: 'Vitamins & Minerals',
        proteinPct: 0.0,
        calciumPctValue: 36.0,
        phosphorusPctValue: 0.02,
        fatPctValue: 0.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 0,
      ),
      Ingredient(
        id: 'supp_dicalcium_phos',
        name: 'Dicalcium Phosphate (21% Ca / 18.5% P)',
        category: 'Vitamins & Minerals',
        proteinPct: 0.0,
        calciumPctValue: 21.0,
        phosphorusPctValue: 18.5,
        fatPctValue: 0.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 0,
      ),
      Ingredient(
        id: 'supp_poultry_probiotic',
        name: 'Direct-Fed Microbial Probiotic Pack',
        category: 'Probiotics & Digestive',
        proteinPct: 12.0,
        calciumPctValue: 0.5,
        phosphorusPctValue: 0.2,
        fatPctValue: 1.0,
        fiberPctValue: 8.0,
        energyMeKcalLb: 500,
      ),
    ]);

    // Pre-populate default items in pantry stock
    _pantryIds.addAll(['usda_corn', 'usda_soybean_meal']);
    _supplementIds.add('supp_calcium_limestone');
  }

  Set<String> get pantryIds => Set.unmodifiable(_pantryIds);
  Set<String> get supplementIds => Set.unmodifiable(_supplementIds);
  List<Ingredient> get ingredients => List.unmodifiable(_ingredients);
  List<Ingredient> get masterIngredients => List.unmodifiable(_ingredients);
  List<SpeciesRequirement> get speciesRequirements => List.unmodifiable(_speciesRequirements);

  List<Ingredient> getAvailableCategories() => ingredients;

  bool isInPantry(String id) => _pantryIds.contains(id);
  bool isInSupplements(String id) => _supplementIds.contains(id);

  void togglePantryItem(String id) {
    if (_pantryIds.contains(id)) {
      _pantryIds.remove(id);
    } else {
      _pantryIds.add(id);
    }
    notifyListeners();
  }

  void toggleSupplementItem(String id) {
    if (_supplementIds.contains(id)) {
      _supplementIds.remove(id);
    } else {
      _supplementIds.add(id);
    }
    notifyListeners();
  }

  /// Adds a new custom ingredient to the master list if it doesn't exist
  void addIngredient(Ingredient ingredient) {
    if (!_ingredients.any((i) => i.id == ingredient.id)) {
      _ingredients.add(ingredient);
    }
    notifyListeners();
  }

  /// Accepts a PantryItem, registers its ingredient, and adds it to pantry stock
  void addPantryItem(PantryItem item) {
    addIngredient(item.ingredient);
    _pantryIds.add(item.ingredient.id);
    notifyListeners();
  }

  List<Ingredient> getPantryIngredients() {
    return _ingredients.where((item) => _pantryIds.contains(item.id)).toList();
  }

  List<Ingredient> getSupplementIngredients() {
    return _ingredients.where((item) => _supplementIds.contains(item.id)).toList();
  }
}