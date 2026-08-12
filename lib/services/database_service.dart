import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/animal_profile.dart';
import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../models/safety_rule.dart';
import '../models/species_catalog.dart';
import '../models/species_requirement.dart';

class DatabaseService extends ChangeNotifier {
  final Set<String> _pantryIds = {};
  final Set<String> _supplementIds = {};
  final List<Ingredient> _ingredients = [];
  final List<SpeciesRequirement> _speciesRequirements = [];
  final List<AnimalProfile> _profiles = [];
  final List<SafetyRule> _safetyRules = [];
  final List<SpeciesCategory> _speciesCatalog = [];

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
    // Raw organ meats & butcher byproducts (prey-model / raw feeding) -
    // real USDA SR-Legacy records that were already in the bundled data
    // dump but never surfaced in the picker.
    'ing_00351': 'Proteins & Meal', // Pork, liver, raw
    'ing_00764': 'Proteins & Meal', // Pork, tongue, raw
    'ing_01114': 'Proteins & Meal', // Beef, heart, raw
    'ing_01938': 'Proteins & Meal', // Beef, kidneys, raw
    'ing_01943': 'Proteins & Meal', // Beef, spleen, raw
    'ing_02289': 'Proteins & Meal', // Bone marrow, raw
    'ing_02683': 'Proteins & Meal', // Beef, thymus (sweetbreads), raw
    'ing_02685': 'Proteins & Meal', // Beef, tongue, raw
    'ing_03088': 'Proteins & Meal', // Beef, tripe, raw
    'ing_03549': 'Proteins & Meal', // Chicken, liver, raw
    'ing_03574': 'Proteins & Meal', // Turkey, gizzard, raw
    'ing_03945': 'Proteins & Meal', // Chicken, gizzard, raw
    'ing_03975': 'Proteins & Meal', // Turkey, liver, raw
    // Dairy & fermented homestead yields.
    'ing_04668': 'Proteins & Meal', // Cottage cheese, creamed
    'ing_03767': 'Proteins & Meal', // Goat milk, fluid
    'ing_03393': 'Proteins & Meal', // Kefir, lowfat, plain
    'ing_05958': 'Natural Supplements', // Vinegar, cider
    'ing_06671': 'Proteins & Meal', // Fish, anchovy, european, raw
    'ing_07608': 'Proteins & Meal', // Fish, mackerel, Atlantic, raw
  };

  // Commercial farm-gate livestock/poultry feeds (Purina, Nutrena,
  // Manna Pro, etc.) from livestock_feeds.json, and exotic/reptile
  // commercial diets (Mazuri, Repashy, etc.) from pet_kibble.json.
  // Both files existed on disk but were never loaded into the app -
  // filed under 'Store Feed' so they appear in the picker's existing
  // commercial-feed bucket alongside store_feeds.json.
  static const List<String> _livestockFeedIngredientIds = [
    'feed_purina_layena_pellets',
    'feed_nutrena_country_feeds_16',
    'feed_scratch_and_peck_layer_16',
    'feed_purina_gamebird_30_starter',
    'feed_purina_gamebird_flight_conditioner',
    'feed_purina_nature_wise_swine_16',
    'feed_manna_pro_goat_balancer_20',
  ];

  static const List<String> _kibbleIngredientIds = [
    'kibble_mazuri_exotic_gamebird_maint',
    'kibble_mazuri_insectivore_diet',
    'kibble_repashy_calcium_plus',
    'kibble_mazuri_tortoise_diet',
    'kibble_purina_proplan_complete_essentials_chicken_rice',
    'kibble_hills_science_diet_adult_chicken_barley',
    'kibble_royal_canin_medium_adult',
    'kibble_blue_buffalo_life_protection_chicken_rice',
    'kibble_taste_of_the_wild_high_prairie',
    'kibble_orijen_original',
    'kibble_stella_chewys_frozen_raw_chicken_patties',
    'kibble_hills_prescription_diet_wd',
  ];

  static const List<String> _storeFeedIngredientIds = [
    'store_nutrena_naturewise_layer_16',
    'store_nutrena_allflock_18_20',
    'store_producers_pride_layer_16',
    'store_dumor_gamebird_maintenance_14',
    'store_producers_pride_allstock_12',
    'store_purina_natures_match_sow_pig',
    'store_nutrena_country_feeds_pig_16',
    'store_dumor_hog_grower',
    'store_nutrena_safechoice_special_care',
    'store_nutrena_triumph_12_8',
    'store_purina_ultium_strategy',
    'store_purina_goat_grower_16',
    'store_nutrena_goat_feed_17',
    'store_nutrebeef_cattle_15',
  ];

  static const _prefsKeyProfiles = 'ff_profiles';
  static const _prefsKeyPantryIds = 'ff_pantry_ids';
  static const _prefsKeySupplementIds = 'ff_supplement_ids';
  static const _prefsKeyCustomIngredients = 'ff_custom_ingredients';

  Future<void> initialize() async {
    if (_ingredients.isEmpty) {
      _seedInitialCatalog();
      await _loadCuratedUsdaIngredients();
      await _loadStoreFeedIngredients();
      await _loadLivestockFeedIngredients();
      await _loadKibbleIngredients();
    }
    if (_speciesRequirements.isEmpty) {
      await _loadSpeciesRequirements();
    }
    if (_safetyRules.isEmpty) {
      await _loadSafetyRules();
    }
    if (_speciesCatalog.isEmpty) {
      await _loadSpeciesCatalog();
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
        'supp_bone_meal',
        'supp_brewers_yeast',
        'supp_calcium_dusting_powder',
        'supp_multivitamin_premix',
        'supp_probiotic_enzyme_blend',
        'supp_amino_acid_isolate',
        'supp_liquid_vitamin_d3',
        'supp_fish_oil',
        'supp_mct_oil',
        'supp_whole_egg_powder',
        'supp_glycine_arginine',
        'usda_milo_sorghum',
        'usda_rye',
        'byprod_wheat_middlings',
        'byprod_rice_bran',
        'meal_canola',
        'meal_sunflower',
        'meal_cottonseed',
        'raw_soybeans_whole',
        'meal_fish',
        'meal_blood',
        'meal_feather',
        'meal_mealworm',
        'forage_alfalfa_hay',
        'forage_timothy_hay',
        'forage_orchard_grass_hay',
        'forage_bermudagrass_hay',
        'forage_corn_silage',
        'forage_wheat_straw',
        'byprod_dried_citrus_pulp',
        'byprod_spent_brewers_grain',
        'forage_setaria_grass',
        'forage_buffel_grass',
        'forage_kikuyu_grass',
        'forage_pangola_grass',
        'forage_sorghum_sudangrass_hay',
        'forage_johnsongrass_hay',
        'forage_pearl_millet',
        'supp_vegetable_oil',
        'supp_tallow',
        'supp_salt',
        'supp_trace_mineral_premix',
        'supp_lysine',
        'supp_methionine',
        ..._curatedUsdaIngredientCategories.keys,
        ..._storeFeedIngredientIds,
        ..._livestockFeedIngredientIds,
        ..._kibbleIngredientIds,
        'supp_taurine',
        'supp_niacin_powder',
        'supp_vitamin_e_oil',
        'supp_cod_liver_oil',
        'supp_kelp_meal',
        'byprod_ddgs',
        'byprod_beet_pulp',
        'supp_nutritional_yeast',
        'meal_shrimp_crab',
        'supp_ground_eggshell',
        'prey_mouse_pinky',
        'prey_mouse_adult',
        'prey_rat_pinky',
        'prey_rat_adult',
        'prey_chick_day_old',
        'prey_quail_whole',
        'prey_rabbit_whole',
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

  // Commercial store-bought feeds (Tractor Supply house brands, Nutrena,
  // Purina, DuMOR, etc.) meant to be used alongside USDA ingredients when
  // building a ration.
  Future<void> _loadStoreFeedIngredients() async {
    try {
      final raw = await rootBundle.loadString('assets/data/store_feeds.json');
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      for (final entry in decoded) {
        _ingredients.add(Ingredient.fromJson(entry as Map<String, dynamic>));
      }
    } catch (e) {
      debugPrint('Failed to load store_feeds.json: $e');
    }
  }

  // Farm-gate livestock/poultry feeds (Purina, Nutrena, Manna Pro, etc.).
  Future<void> _loadLivestockFeedIngredients() async {
    try {
      final raw = await rootBundle.loadString('assets/data/livestock_feeds.json');
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      for (final entry in decoded) {
        final record = Map<String, dynamic>.from(entry as Map<String, dynamic>);
        record['category'] = 'Store Feed';
        _convertKgEnergyToLb(record);
        _ingredients.add(Ingredient.fromJson(record));
      }
    } catch (e) {
      debugPrint('Failed to load livestock_feeds.json: $e');
    }
  }

  // Commercial exotic/reptile/specialty diets (Mazuri, Repashy, etc.).
  Future<void> _loadKibbleIngredients() async {
    try {
      final raw = await rootBundle.loadString('assets/data/pet_kibble.json');
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      for (final entry in decoded) {
        final record = Map<String, dynamic>.from(entry as Map<String, dynamic>);
        record['category'] = 'Store Feed';
        _convertKgEnergyToLb(record);
        _ingredients.add(Ingredient.fromJson(record));
      }
    } catch (e) {
      debugPrint('Failed to load pet_kibble.json: $e');
    }
  }

  // livestock_feeds.json/pet_kibble.json publish ME as kcal/kg, matching
  // how manufacturers print it on the bag, but AsFedMetrics.energyKcalLb
  // (and AsFedMetrics.fromJson's 'metabolicEnergyKcal' fallback) expects
  // kcal/lb - so it has to be converted at load time or every value here
  // reads ~2.2x too high.
  void _convertKgEnergyToLb(Map<String, dynamic> record) {
    final metrics = record['asFedMetrics'];
    if (metrics is Map<String, dynamic> && metrics['energyKcalLb'] == null) {
      final kcalPerKg = metrics['metabolicEnergyKcal'];
      if (kcalPerKg is num) {
        metrics['energyKcalLb'] = kcalPerKg / 2.20462;
      }
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

  Future<void> _loadSafetyRules() async {
    try {
      final raw = await rootBundle.loadString('assets/data/safety_rules.json');
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _safetyRules.addAll(
        decoded.map((e) => SafetyRule.fromJson(e as Map<String, dynamic>)),
      );
    } catch (e) {
      debugPrint('Failed to load safety_rules.json: $e');
    }
  }

  Future<void> _loadSpeciesCatalog() async {
    try {
      final raw = await rootBundle.loadString('assets/data/species_catalog.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final categories = decoded['categories'] as List<dynamic>? ?? [];
      _speciesCatalog.addAll(
        categories.map((e) => SpeciesCategory.fromJson(e as Map<String, dynamic>)),
      );
    } catch (e) {
      debugPrint('Failed to load species_catalog.json: $e');
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
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 8.5,
          calciumPct: 0.02,
          phosphorusPct: 0.28,
          fatPct: 3.8,
          fiberPct: 2.2,
          energyKcalLb: 1550,
          niacinMgKg: 24,
          copperPpm: 3.0,
          molybdenumPpm: 0.5,
          dryMatterPct: 86.0,
        ),
      ),
      Ingredient(
        id: 'usda_barley',
        name: 'USDA Barley, Grain, Pearl, Raw',
        category: 'Grains & Cereals',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 12.48,
          calciumPct: 0.03,
          phosphorusPct: 0.26,
          fatPct: 2.3,
          fiberPct: 17.3,
          energyKcalLb: 1400,
          niacinMgKg: 55,
          copperPpm: 3.0,
          molybdenumPpm: 0.5,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'usda_soybean_meal',
        name: 'Soybean Meal 48%',
        category: 'Proteins & Meal',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 48.0,
          calciumPct: 0.20,
          phosphorusPct: 0.65,
          fatPct: 1.0,
          fiberPct: 3.5,
          energyKcalLb: 1100,
          niacinMgKg: 30,
          dryMatterPct: 90.0,
        ),
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
        dryMatterPct: 92.0,
      ),

      // Supplements & Additives
      Ingredient(
        id: 'supp_calcium_limestone',
        name: 'Calcium Carbonate / Ground Limestone (38% Ca)',
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

      // Nutrient library additions - real macro data used where a real USDA
      // record exists (fish oil, whole egg powder); the rest are hand-authored
      // from standard published feed-supplement values, since these are
      // manufactured products, not whole foods, and won't show up in a USDA
      // SR-Legacy dataset. A few (vitamin D3, multivitamin premix, glycine/
      // arginine) don't have a meaningful macro-nutrient profile in this
      // app's model at all - they're included so they're selectable, with
      // zeroed tracked fields rather than a fabricated number.
      Ingredient(
        id: 'supp_bone_meal',
        name: 'Bone Meal (Naturally Sourced)',
        category: 'Vitamins & Minerals',
        proteinPct: 11.0,
        calciumPctValue: 24.0,
        phosphorusPctValue: 12.0,
        fatPctValue: 2.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 400,
      ),
      Ingredient(
        id: 'supp_brewers_yeast',
        name: "Brewer's Yeast (Niacin / B-Vitamin Support)",
        category: 'Natural Supplements',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 45.0,
          calciumPct: 0.15,
          phosphorusPct: 1.4,
          fatPct: 1.5,
          fiberPct: 3.0,
          energyKcalLb: 1300,
          niacinMgKg: 400,
        ),
      ),
      Ingredient(
        id: 'supp_calcium_dusting_powder',
        name: 'Calcium Dusting Powder (No D3)',
        category: 'Vitamins & Minerals',
        proteinPct: 0.0,
        calciumPctValue: 38.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 0.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 0,
      ),
      Ingredient(
        id: 'supp_multivitamin_premix',
        name: 'Commercial Multivitamin Premix',
        category: 'Vitamins & Minerals',
        proteinPct: 0.0,
        calciumPctValue: 0.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 0.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 0,
      ),
      Ingredient(
        id: 'supp_probiotic_enzyme_blend',
        name: 'Probiotic / Enzyme Blend',
        category: 'Probiotics & Digestive',
        proteinPct: 10.0,
        calciumPctValue: 0.3,
        phosphorusPctValue: 0.2,
        fatPctValue: 1.0,
        fiberPctValue: 5.0,
        energyMeKcalLb: 400,
      ),
      Ingredient(
        id: 'supp_amino_acid_isolate',
        name: 'Amino Acid Isolate (Lysine + Methionine)',
        category: 'Vitamins & Minerals',
        asFedMetrics: AsFedMetrics(
          lysinePct: 50.0,
          methioninePct: 50.0,
        ),
      ),
      Ingredient(
        id: 'supp_liquid_vitamin_d3',
        name: 'Liquid Vitamin D3',
        category: 'Vitamins & Minerals',
        proteinPct: 0.0,
        calciumPctValue: 0.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 0.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 0,
      ),
      Ingredient(
        id: 'supp_fish_oil',
        name: 'Fish Oil',
        category: 'Natural Supplements',
        proteinPct: 0.0,
        calciumPctValue: 0.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 100.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 4092,
      ),
      Ingredient(
        id: 'supp_mct_oil',
        name: 'MCT Oil',
        category: 'Natural Supplements',
        proteinPct: 0.0,
        calciumPctValue: 0.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 100.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 4092,
      ),
      Ingredient(
        id: 'supp_whole_egg_powder',
        name: 'Whole Egg Powder',
        category: 'Natural Supplements',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 48.05,
          fatPct: 43.9,
          calciumPct: 0.244,
          phosphorusPct: 0.629,
          sodiumPct: 0.476,
          energyKcalLb: 2685,
        ),
      ),
      Ingredient(
        id: 'supp_glycine_arginine',
        name: 'Glycine & L-Arginine',
        category: 'Vitamins & Minerals',
        proteinPct: 0.0,
        calciumPctValue: 0.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 0.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 0,
      ),

      // More grains/byproducts - hand-authored from standard published feed
      // composition tables (values are as-fed, ballpark/hobbyist precision,
      // matching the rest of this seeded catalog rather than a lab assay).
      Ingredient(
        id: 'usda_milo_sorghum',
        name: 'Milo / Grain Sorghum',
        category: 'Grains & Cereals',
        proteinPct: 9.0,
        calciumPctValue: 0.03,
        phosphorusPctValue: 0.28,
        fatPctValue: 2.8,
        fiberPctValue: 2.0,
        energyMeKcalLb: 1500,
        dryMatterPct: 86.0,
      ),
      Ingredient(
        id: 'usda_rye',
        name: 'Rye, Grain',
        category: 'Grains & Cereals',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 12.0,
          calciumPct: 0.05,
          phosphorusPct: 0.35,
          fatPct: 1.7,
          fiberPct: 2.2,
          energyKcalLb: 1360,
          niacinMgKg: 18,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'byprod_wheat_middlings',
        name: 'Wheat Middlings (Wheat Mill Run)',
        category: 'Grains & Cereals',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 16.0,
          calciumPct: 0.1,
          phosphorusPct: 0.9,
          fatPct: 4.0,
          fiberPct: 8.0,
          energyKcalLb: 1220,
          niacinMgKg: 85,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'byprod_rice_bran',
        name: 'Rice Bran',
        category: 'Grains & Cereals',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 13.0,
          calciumPct: 0.07,
          phosphorusPct: 1.7,
          fatPct: 13.0,
          fiberPct: 12.0,
          energyKcalLb: 1315,
          niacinMgKg: 300,
          dryMatterPct: 88.0,
        ),
      ),

      // Plant & animal protein meals.
      Ingredient(
        id: 'meal_canola',
        name: 'Canola Meal',
        category: 'Proteins & Meal',
        proteinPct: 36.0,
        calciumPctValue: 0.65,
        phosphorusPctValue: 1.0,
        fatPctValue: 2.0,
        fiberPctValue: 12.0,
        energyMeKcalLb: 900,
        dryMatterPct: 90.0,
      ),
      Ingredient(
        id: 'meal_sunflower',
        name: 'Sunflower Meal',
        category: 'Proteins & Meal',
        proteinPct: 34.0,
        calciumPctValue: 0.4,
        phosphorusPctValue: 1.0,
        fatPctValue: 2.5,
        fiberPctValue: 13.0,
        energyMeKcalLb: 860,
        dryMatterPct: 90.0,
      ),
      Ingredient(
        id: 'meal_cottonseed',
        name: 'Cottonseed Meal',
        category: 'Proteins & Meal',
        proteinPct: 41.0,
        calciumPctValue: 0.2,
        phosphorusPctValue: 1.1,
        fatPctValue: 4.0,
        fiberPctValue: 12.0,
        energyMeKcalLb: 900,
        dryMatterPct: 90.0,
      ),
      Ingredient(
        id: 'meal_fish',
        name: 'Fish Meal (Menhaden, 60% CP)',
        category: 'Proteins & Meal',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 60.0,
          calciumPct: 5.0,
          phosphorusPct: 3.0,
          fatPct: 9.0,
          fiberPct: 1.0,
          energyKcalLb: 1300,
          niacinMgKg: 60,
          taurinePct: 0.3,
          dryMatterPct: 92.0,
        ),
      ),
      Ingredient(
        id: 'meal_blood',
        name: 'Blood Meal',
        category: 'Proteins & Meal',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 80.0,
          calciumPct: 0.3,
          phosphorusPct: 0.25,
          fatPct: 1.0,
          fiberPct: 1.0,
          energyKcalLb: 1130,
          taurinePct: 0.05,
          dryMatterPct: 92.0,
        ),
      ),
      Ingredient(
        id: 'meal_feather',
        name: 'Feather Meal (Hydrolyzed)',
        category: 'Proteins & Meal',
        proteinPct: 85.0,
        calciumPctValue: 0.2,
        phosphorusPctValue: 0.5,
        fatPctValue: 3.0,
        fiberPctValue: 1.0,
        energyMeKcalLb: 1000,
        dryMatterPct: 92.0,
      ),
      Ingredient(
        id: 'raw_soybeans_whole',
        name: 'Raw Soybeans, Whole (Untoasted)',
        category: 'Proteins & Meal',
        proteinPct: 37.0,
        calciumPctValue: 0.25,
        phosphorusPctValue: 0.6,
        fatPctValue: 18.0,
        fiberPctValue: 5.0,
        energyMeKcalLb: 1400,
        dryMatterPct: 88.0,
      ),
      Ingredient(
        id: 'meal_mealworm',
        name: 'Mealworm Meal (Dried)',
        category: 'Proteins & Meal',
        proteinPct: 53.0,
        calciumPctValue: 0.3,
        phosphorusPctValue: 0.7,
        fatPctValue: 28.0,
        fiberPctValue: 6.0,
        energyMeKcalLb: 1900,
        dryMatterPct: 92.0,
      ),

      // Forages & roughage - the ration base that pasture/hay-dependent
      // species (ruminants, equines, rabbits) need and this catalog had
      // none of before. Corn silage and straw are on an as-fed basis, so
      // their numbers read much lower than the dry hays - that reflects
      // moisture/bulk content, not a data error.
      Ingredient(
        id: 'forage_alfalfa_hay',
        name: 'Alfalfa Hay (Mid-Bloom)',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 17.0,
          calciumPct: 1.2,
          phosphorusPct: 0.22,
          fatPct: 2.0,
          fiberPct: 28.0,
          energyKcalLb: 1000,
          niacinMgKg: 40,
          copperPpm: 9.0,
          molybdenumPpm: 2.0,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'forage_timothy_hay',
        name: 'Timothy Hay',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 8.0,
          calciumPct: 0.4,
          phosphorusPct: 0.2,
          fatPct: 2.0,
          fiberPct: 30.0,
          energyKcalLb: 850,
          copperPpm: 6.0,
          molybdenumPpm: 1.5,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'forage_orchard_grass_hay',
        name: 'Orchard Grass Hay',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 10.0,
          calciumPct: 0.3,
          phosphorusPct: 0.25,
          fatPct: 2.5,
          fiberPct: 29.0,
          energyKcalLb: 900,
          copperPpm: 6.0,
          molybdenumPpm: 1.2,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'forage_bermudagrass_hay',
        name: 'Bermudagrass Hay',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 9.0,
          calciumPct: 0.4,
          phosphorusPct: 0.2,
          fatPct: 1.8,
          fiberPct: 30.0,
          energyKcalLb: 800,
          copperPpm: 6.0,
          molybdenumPpm: 1.0,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'forage_corn_silage',
        name: 'Corn Silage',
        category: 'Forages & Roughage',
        proteinPct: 2.8,
        calciumPctValue: 0.1,
        phosphorusPctValue: 0.08,
        fatPctValue: 1.2,
        fiberPctValue: 8.0,
        energyMeKcalLb: 350,
        dryMatterPct: 35.0,
      ),
      Ingredient(
        id: 'forage_wheat_straw',
        name: 'Wheat Straw',
        category: 'Forages & Roughage',
        proteinPct: 3.5,
        calciumPctValue: 0.2,
        phosphorusPctValue: 0.06,
        fatPctValue: 1.5,
        fiberPctValue: 38.0,
        energyMeKcalLb: 500,
        dryMatterPct: 90.0,
      ),
      Ingredient(
        id: 'byprod_dried_citrus_pulp',
        name: 'Dried Citrus Pulp',
        category: 'Forages & Roughage',
        proteinPct: 6.0,
        calciumPctValue: 1.8,
        phosphorusPctValue: 0.12,
        fatPctValue: 3.0,
        fiberPctValue: 12.0,
        energyMeKcalLb: 1250,
        dryMatterPct: 90.0,
      ),
      Ingredient(
        id: 'byprod_spent_brewers_grain',
        name: 'Spent Brewers Grain (Dried)',
        category: 'Forages & Roughage',
        proteinPct: 25.0,
        calciumPctValue: 0.3,
        phosphorusPctValue: 0.55,
        fatPctValue: 7.0,
        fiberPctValue: 15.0,
        energyMeKcalLb: 1150,
        dryMatterPct: 90.0,
      ),

      // Tropical/subtropical pasture grasses - chronically high in soluble
      // oxalates, which bind dietary calcium and cause "Big Head" disease
      // (nutritional secondary hyperparathyroidism) in horses and
      // hypocalcemia in ruminants grazing them long-term. Oxalate % is a
      // relatively fixed trait of the grass species itself (unlike nitrate,
      // which swings with weather), so it's tracked as a static value here.
      Ingredient(
        id: 'forage_setaria_grass',
        name: 'Setaria Grass (Pasture/Hay)',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 9.0,
          calciumPct: 0.35,
          phosphorusPct: 0.22,
          fatPct: 2.0,
          fiberPct: 30.0,
          energyKcalLb: 800,
          oxalatePct: 3.0,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'forage_buffel_grass',
        name: 'Buffel Grass (Cenchrus ciliaris)',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 8.0,
          calciumPct: 0.4,
          phosphorusPct: 0.2,
          fatPct: 1.8,
          fiberPct: 32.0,
          energyKcalLb: 780,
          oxalatePct: 2.0,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'forage_kikuyu_grass',
        name: 'Kikuyu Grass (Pasture/Hay)',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 12.0,
          calciumPct: 0.4,
          phosphorusPct: 0.3,
          fatPct: 2.2,
          fiberPct: 26.0,
          energyKcalLb: 820,
          oxalatePct: 3.2,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'forage_pangola_grass',
        name: 'Pangola Grass (Pasture/Hay)',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 7.0,
          calciumPct: 0.35,
          phosphorusPct: 0.2,
          fatPct: 1.8,
          fiberPct: 31.0,
          energyKcalLb: 770,
          oxalatePct: 1.8,
          dryMatterPct: 88.0,
        ),
      ),

      // Nitrate-accumulator forages - risk is driven by growing conditions
      // (drought, frost, heavy nitrogen fertilization, lush regrowth), not a
      // fixed property of the plant, so no numeric nitrate value is stored
      // here - see the advisory-only safety rules keyed to these ids/names
      // instead of a computed ppm threshold.
      Ingredient(
        id: 'forage_sorghum_sudangrass_hay',
        name: 'Sorghum-Sudangrass Hay',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 10.0,
          calciumPct: 0.4,
          phosphorusPct: 0.25,
          fatPct: 1.8,
          fiberPct: 28.0,
          energyKcalLb: 830,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'forage_johnsongrass_hay',
        name: 'Johnsongrass Hay',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 9.0,
          calciumPct: 0.4,
          phosphorusPct: 0.22,
          fatPct: 1.7,
          fiberPct: 29.0,
          energyKcalLb: 800,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'forage_pearl_millet',
        name: 'Pearl Millet Forage/Hay',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 11.0,
          calciumPct: 0.4,
          phosphorusPct: 0.3,
          fatPct: 2.0,
          fiberPct: 27.0,
          energyKcalLb: 850,
          dryMatterPct: 88.0,
        ),
      ),

      // Fats & oils - filed under Natural Supplements like the existing
      // fish/MCT oil entries, so they show up in the same supplement picker.
      Ingredient(
        id: 'supp_vegetable_oil',
        name: 'Vegetable Oil',
        category: 'Natural Supplements',
        proteinPct: 0.0,
        calciumPctValue: 0.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 100.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 4092,
      ),
      Ingredient(
        id: 'supp_tallow',
        name: 'Tallow (Rendered Animal Fat)',
        category: 'Natural Supplements',
        proteinPct: 0.0,
        calciumPctValue: 0.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 100.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 4092,
      ),

      // Micro-ingredients & concentrates.
      Ingredient(
        id: 'supp_salt',
        name: 'Salt (NaCl)',
        category: 'Vitamins & Minerals',
        asFedMetrics: AsFedMetrics(
          sodiumPct: 39.0,
        ),
      ),
      Ingredient(
        id: 'supp_trace_mineral_premix',
        name: 'Trace Mineral Premix (Zn/Cu/Mn/Se/I)',
        category: 'Vitamins & Minerals',
        asFedMetrics: AsFedMetrics(
          // Generic all-species premix, not formulated copper-free - real
          // copper content this high is exactly why the sheep-specific
          // keyword caution on this ingredient already exists.
          copperPpm: 20.0,
          molybdenumPpm: 1.0,
        ),
      ),
      Ingredient(
        id: 'supp_lysine',
        name: 'L-Lysine HCl',
        category: 'Vitamins & Minerals',
        asFedMetrics: AsFedMetrics(
          lysinePct: 78.0,
        ),
      ),
      Ingredient(
        id: 'supp_methionine',
        name: 'DL-Methionine',
        category: 'Vitamins & Minerals',
        asFedMetrics: AsFedMetrics(
          methioninePct: 99.0,
        ),
      ),

      // Targeted micronutrient "gap filler" single-additives - standard
      // published feed-supplement values, hand-authored like the entries
      // above since these are manufactured/processed products rather than
      // whole foods in the USDA SR-Legacy dump. Vitamin E oil has no
      // tracked macro field in this app's model, so it's zeroed like the
      // existing Liquid Vitamin D3 entry - included so it's selectable.
      Ingredient(
        id: 'supp_taurine',
        name: 'Taurine Powder',
        category: 'Vitamins & Minerals',
        asFedMetrics: AsFedMetrics(
          taurinePct: 100.0,
        ),
      ),
      Ingredient(
        id: 'supp_niacin_powder',
        name: 'Niacin / Vitamin B3 Powder',
        category: 'Vitamins & Minerals',
        asFedMetrics: AsFedMetrics(
          niacinMgKg: 1000000.0,
        ),
      ),
      Ingredient(
        id: 'supp_vitamin_e_oil',
        name: 'Vitamin E Oil',
        category: 'Vitamins & Minerals',
        proteinPct: 0.0,
        calciumPctValue: 0.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 0.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 0,
      ),
      Ingredient(
        id: 'supp_cod_liver_oil',
        name: 'Cod Liver Oil (Vitamin A & D)',
        category: 'Natural Supplements',
        proteinPct: 0.0,
        calciumPctValue: 0.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 100.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 4092,
      ),
      Ingredient(
        id: 'supp_kelp_meal',
        name: 'Kelp Meal (Iodine / Trace Minerals)',
        category: 'Natural Supplements',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 8.0,
          calciumPct: 2.0,
          phosphorusPct: 0.3,
          fatPct: 1.0,
          fiberPct: 7.0,
          energyKcalLb: 600,
        ),
      ),
      Ingredient(
        id: 'byprod_ddgs',
        name: 'Distillers Dried Grains with Solubles (DDGS)',
        category: 'Grains & Cereals',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 27.0,
          calciumPct: 0.05,
          phosphorusPct: 0.83,
          fatPct: 10.0,
          fiberPct: 7.0,
          energyKcalLb: 1550,
        ),
      ),
      Ingredient(
        id: 'byprod_beet_pulp',
        name: 'Beet Pulp (Dried Shreds, No Molasses)',
        category: 'Forages & Roughage',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 9.0,
          calciumPct: 0.7,
          phosphorusPct: 0.1,
          fatPct: 0.5,
          fiberPct: 19.0,
          energyKcalLb: 1100,
        ),
      ),
      Ingredient(
        id: 'supp_nutritional_yeast',
        name: 'Nutritional Yeast (Deactivated)',
        category: 'Natural Supplements',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 50.0,
          calciumPct: 0.05,
          phosphorusPct: 1.3,
          fatPct: 5.0,
          fiberPct: 25.0,
          energyKcalLb: 1500,
          niacinMgKg: 400,
        ),
      ),
      Ingredient(
        id: 'meal_shrimp_crab',
        name: 'Shrimp & Crab Meal',
        category: 'Proteins & Meal',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 40.0,
          calciumPct: 6.0,
          phosphorusPct: 1.2,
          fatPct: 4.0,
          fiberPct: 10.0,
          energyKcalLb: 1000,
        ),
      ),
      Ingredient(
        id: 'supp_ground_eggshell',
        name: 'Ground Eggshell (Calcium Carbonate)',
        category: 'Vitamins & Minerals',
        proteinPct: 0.0,
        calciumPctValue: 37.0,
        phosphorusPctValue: 0.0,
        fatPctValue: 0.0,
        fiberPctValue: 0.0,
        energyMeKcalLb: 0,
      ),

      // Whole prey (raptor/reptile feeding). Source values are the Merck/
      // MSD Veterinary Manual "Proximate Analysis of Whole Prey" table
      // (itself drawn from published zoo/exotic-nutrition studies), which
      // reports crude protein/fat/calcium/phosphorus on a dry-matter (DM)
      // basis alongside each species' DM%. Converted here to as-fed (%
      // asFed = %DM x DM_fraction) to match this app's convention.
      // Energy isn't published in that table, so it's estimated from the
      // as-fed protein/fat via the standard modified-Atwater factors used
      // for animal-tissue diets (protein 4 kcal/g, fat 9 kcal/g).
      Ingredient(
        id: 'prey_mouse_pinky',
        name: 'Whole Prey - Mouse, Pinky/Baby',
        category: 'Whole Prey',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 14.2,
          calciumPct: 0.31,
          phosphorusPct: 0.37,
          fatPct: 4.2,
          energyKcalLb: 428,
        ),
      ),
      Ingredient(
        id: 'prey_mouse_adult',
        name: 'Whole Prey - Mouse, Adult',
        category: 'Whole Prey',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 15.4,
          calciumPct: 0.53,
          phosphorusPct: 0.42,
          fatPct: 8.0,
          energyKcalLb: 606,
        ),
      ),
      Ingredient(
        id: 'prey_rat_pinky',
        name: 'Whole Prey - Rat, Pinky/Baby',
        category: 'Whole Prey',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 13.5,
          calciumPct: 0.35,
          phosphorusPct: 0.23,
          fatPct: 4.3,
          energyKcalLb: 423,
        ),
      ),
      Ingredient(
        id: 'prey_rat_adult',
        name: 'Whole Prey - Rat, Adult',
        category: 'Whole Prey',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 17.8,
          calciumPct: 0.83,
          phosphorusPct: 0.51,
          fatPct: 7.9,
          energyKcalLb: 645,
        ),
      ),
      Ingredient(
        id: 'prey_chick_day_old',
        name: 'Whole Prey - Day-Old Chick',
        category: 'Whole Prey',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 16.6,
          calciumPct: 0.33,
          phosphorusPct: 0.23,
          fatPct: 6.2,
          energyKcalLb: 553,
        ),
      ),
      // Phosphorus not published for quail in the source table; estimated
      // here from the Ca:P ratio of the other whole-bird rows in the same
      // table (day-old chick, whole chicken), not directly sourced.
      Ingredient(
        id: 'prey_quail_whole',
        name: 'Whole Prey - Quail, Whole',
        category: 'Whole Prey',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 21.7,
          calciumPct: 1.26,
          phosphorusPct: 0.92,
          fatPct: 9.8,
          energyKcalLb: 791,
        ),
      ),
      Ingredient(
        id: 'prey_rabbit_whole',
        name: 'Whole Prey - Rabbit, Adult',
        category: 'Whole Prey',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 19.1,
          calciumPct: 0.73,
          phosphorusPct: 0.73,
          fatPct: 7.2,
          energyKcalLb: 638,
        ),
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
  List<SafetyRule> get safetyRules => List.unmodifiable(_safetyRules);
  List<SpeciesCategory> get speciesCatalog => List.unmodifiable(_speciesCatalog);

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