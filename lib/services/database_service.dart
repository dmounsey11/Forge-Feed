import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/animal_profile.dart';
import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../models/species_requirement.dart';

class DatabaseService extends ChangeNotifier {
  final Set<String> _pantryIds = {};
  final Set<String> _supplementIds = {};
  final List<Ingredient> _ingredients = [];
  final List<SpeciesRequirement> _speciesRequirements = [];
  final List<AnimalProfile> _profiles = [];

  // Hand-picked allow-list of genuinely whole-food, feed-relevant records
  // out of assets/data/ingredients.json (a raw USDA SR-Legacy human-food
  // dump - most of it, e.g. branded snacks, is not appropriate to surface
  // as feed ingredients, so we curate rather than bulk-load it).
  static const Map<String, String> _curatedUsdaIngredientCategories = {
    'ing_02487': 'Grains & Cereals', // Corn, sweet, yellow, raw
    'ing_02772': 'Grains & Cereals', // Barley, hulled
    'ing_02192': 'Grains & Cereals', // Rice, brown, long-grain, raw
    'ing_01378': 'Grains & Cereals', // Wheat, hard red spring
    'ing_02194': 'Grains & Cereals', // Oats
    'ing_03541': 'Proteins & Meal', // Chicken, broilers or fryers, meat only, raw
    'ing_01141': 'Proteins & Meal', // Beef, ground, 70% lean meat / 30% fat, raw
    'ing_06175': 'Proteins & Meal', // Fish, salmon, Atlantic, wild, raw
    'ing_07628': 'Proteins & Meal', // Fish, sardine, Atlantic, canned in oil, drained solids with bone
    'ing_01940': 'Proteins & Meal', // Beef, variety meats and by-products, liver, raw
    'ing_03776': 'Proteins & Meal', // Egg, whole, raw, fresh
    'ing_00910': 'Produce', // Kale, raw
    'ing_00937': 'Produce', // Pumpkin, raw
    'ing_00951': 'Produce', // Spinach, raw
    'ing_02882': 'Produce', // Carrots, raw
    'ing_00971': 'Produce', // Sweet potato, raw, unprepared
    'ing_00946': 'Natural Supplements', // Seaweed, kelp, raw
    'ing_01903': 'Natural Supplements', // Seeds, flaxseed
  };

  static const _prefsKeyProfiles = 'ff_profiles';
  static const _prefsKeyPantryIds = 'ff_pantry_ids';
  static const _prefsKeySupplementIds = 'ff_supplement_ids';
  static const _prefsKeyCustomIngredients = 'ff_custom_ingredients';

  Future<void> initialize() async {
    if (_ingredients.isEmpty) {
      _seedInitialCatalog();
      await _loadCuratedUsdaIngredients();
    }
    if (_speciesRequirements.isEmpty) {
      await _loadSpeciesRequirements();
    }

    final prefs = await SharedPreferences.getInstance();
    _loadPersistedProfiles(prefs);
    _loadPersistedPantryState(prefs);

    notifyListeners();
  }

  Set<String> get _builtInIngredientIds => {
        'usda_corn',
        'usda_barley',
        'usda_soybean_meal',
        'usda_black_soldier_fly',
        'supp_calcium_limestone',
        'supp_oyster_shell',
        'supp_dicalcium_phos',
        'supp_poultry_probiotic',
        ..._curatedUsdaIngredientCategories.keys,
      };

  void _loadPersistedProfiles(SharedPreferences prefs) {
    final stored = prefs.getStringList(_prefsKeyProfiles);
    if (stored != null) {
      _profiles
        ..clear()
        ..addAll(stored.map((s) => AnimalProfile.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    } else if (_profiles.isEmpty) {
      _seedInitialProfiles();
    }
  }

  void _loadPersistedPantryState(SharedPreferences prefs) {
    final customIngredients = prefs.getStringList(_prefsKeyCustomIngredients) ?? [];
    for (final s in customIngredients) {
      final ingredient = Ingredient.fromJson(jsonDecode(s) as Map<String, dynamic>);
      if (!_ingredients.any((i) => i.id == ingredient.id)) {
        _ingredients.add(ingredient);
      }
    }

    final pantryIds = prefs.getStringList(_prefsKeyPantryIds);
    if (pantryIds != null) {
      _pantryIds
        ..clear()
        ..addAll(pantryIds);
    }

    final supplementIds = prefs.getStringList(_prefsKeySupplementIds);
    if (supplementIds != null) {
      _supplementIds
        ..clear()
        ..addAll(supplementIds);
    }
  }

  Future<void> _persistProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKeyProfiles,
      _profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> _persistPantryState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeyPantryIds, _pantryIds.toList());
    await prefs.setStringList(_prefsKeySupplementIds, _supplementIds.toList());
    final builtIn = _builtInIngredientIds;
    await prefs.setStringList(
      _prefsKeyCustomIngredients,
      _ingredients.where((i) => !builtIn.contains(i.id)).map((i) => jsonEncode(i.toJson())).toList(),
    );
  }

  Future<void> _loadCuratedUsdaIngredients() async {
    try {
      final raw = await rootBundle.loadString('assets/data/ingredients.json');
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      for (final entry in decoded) {
        final record = entry as Map<String, dynamic>;
        final category = _curatedUsdaIngredientCategories[record['id']];
        if (category == null) continue;
        _ingredients.add(Ingredient.fromUsdaJson(record, categoryOverride: category));
      }
    } catch (e) {
      debugPrint('Failed to load ingredients.json: $e');
    }
  }

  Future<void> _loadSpeciesRequirements() async {
    try {
      final raw = await rootBundle.loadString('assets/data/animal_requirements.json');
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _speciesRequirements.addAll(
        decoded.map((e) => SpeciesRequirement.fromJson(e as Map<String, dynamic>)),
      );
    } catch (e) {
      debugPrint('Failed to load animal_requirements.json: $e');
    }
  }

  void _seedInitialProfiles() {
    _profiles.addAll([
      AnimalProfile(
        id: '1',
        name: 'Main Backyard Flock',
        species: 'Livestock: Poultry (Chicken)',
        headCount: 12,
        productionStage: 'Active Layer',
        environment: 'Outdoor',
      ),
      AnimalProfile(
        id: '2',
        name: 'Coturnix Quail Pens',
        species: 'Livestock: Poultry (Quail)',
        headCount: 24,
        productionStage: 'Breeder / Production',
        environment: 'Outdoor',
      ),
    ]);
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
  List<AnimalProfile> get profiles => List.unmodifiable(_profiles);

  void addProfile(AnimalProfile profile) {
    _profiles.add(profile);
    notifyListeners();
    unawaited(_persistProfiles());
  }

  void updateProfile(AnimalProfile profile) {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
      notifyListeners();
      unawaited(_persistProfiles());
    }
  }

  void deleteProfile(String id) {
    _profiles.removeWhere((p) => p.id == id);
    notifyListeners();
    unawaited(_persistProfiles());
  }

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
    unawaited(_persistPantryState());
  }

  void toggleSupplementItem(String id) {
    if (_supplementIds.contains(id)) {
      _supplementIds.remove(id);
    } else {
      _supplementIds.add(id);
    }
    notifyListeners();
    unawaited(_persistPantryState());
  }

  /// Adds a new custom ingredient to the master list if it doesn't exist
  void addIngredient(Ingredient ingredient) {
    if (!_ingredients.any((i) => i.id == ingredient.id)) {
      _ingredients.add(ingredient);
    }
    notifyListeners();
    unawaited(_persistPantryState());
  }

  /// Accepts a PantryItem, registers its ingredient, and adds it to pantry stock
  void addPantryItem(PantryItem item) {
    addIngredient(item.ingredient);
    _pantryIds.add(item.ingredient.id);
    notifyListeners();
    unawaited(_persistPantryState());
  }

  List<Ingredient> getPantryIngredients() {
    return _ingredients.where((item) => _pantryIds.contains(item.id)).toList();
  }

  List<Ingredient> getSupplementIngredients() {
    return _ingredients.where((item) => _supplementIds.contains(item.id)).toList();
  }
}