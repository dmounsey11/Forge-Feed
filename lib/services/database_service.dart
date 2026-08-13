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
    'ing_02976': 'Produce', // Squash, summer, all varieties, raw
    'ing_02978': 'Produce', // Squash, winter, all varieties, raw
    'ing_01780': 'Produce', // Squash, summer, zucchini, includes skin, raw
    'ing_00898': 'Produce', // Cucumber, with peel, raw
    'ing_02946': 'Produce', // Tomatoes, red, ripe, raw, year round average
    'ing_02515': 'Produce', // Potatoes, flesh and skin, raw
    'ing_02477': 'Produce', // Celery, raw
    'ing_01737': 'Produce', // Lettuce, iceberg (includes crisphead types), raw
    'ing_01736': 'Produce', // Lettuce, cos or romaine, raw
    'ing_04177': 'Fruits', // Apples, raw, with skin
    'ing_06433': 'Fruits', // Bananas, raw
    'ing_04200': 'Fruits', // Blueberries, raw
    'ing_00251': 'Fruits', // Strawberries, raw
    'ing_00254': 'Fruits', // Watermelon, raw
    'ing_07172': 'Fruits', // Grapes, red or green (European type), raw
    'ing_02408': 'Fruits', // Oranges, raw, with peel
    'ing_01607': 'Fruits', // Pears, raw
    'ing_04211': 'Fruits', // Cranberries, raw
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

  // Retags the pre-existing curated Produce/Fruits USDA records into the
  // named fruit/vegetable subcategory taxonomy added alongside the
  // hand-authored fruit_*/veg_* library below, without touching their ids
  // or nutrient data (some ids may already be referenced by saved profiles
  // or pantry state).
  static const Map<String, String> _curatedUsdaSubCategoryOverrides = {
    'ing_00910': 'Leafy Greens & Forage Produce', // Kale
    'ing_00937': 'Squash & Cucurbits', // Pumpkin
    'ing_00951': 'Leafy Greens & Forage Produce', // Spinach
    'ing_02882': 'Root Vegetables & Tubers', // Carrots
    'ing_00971': 'Root Vegetables & Tubers', // Sweet potato
    'ing_02976': 'Squash & Cucurbits', // Squash, summer
    'ing_02978': 'Squash & Cucurbits', // Squash, winter
    'ing_01780': 'Squash & Cucurbits', // Zucchini
    'ing_00898': 'Squash & Cucurbits', // Cucumber
    'ing_02946': 'Fruiting Vegetables & Nightshades', // Tomatoes
    'ing_02515': 'Root Vegetables & Tubers', // Potatoes
    'ing_02477': 'Stalk & Bulb', // Celery
    'ing_01737': 'Leafy Greens & Forage Produce', // Lettuce, iceberg
    'ing_01736': 'Leafy Greens & Forage Produce', // Lettuce, romaine
    'ing_04177': 'Common & Core Staples', // Apples
    'ing_06433': 'Common & Core Staples', // Bananas
    'ing_04200': 'Common & Core Staples', // Blueberries
    'ing_00251': 'Common & Core Staples', // Strawberries
    'ing_00254': 'Melons & High-Moisture', // Watermelon
    'ing_07172': 'Specialty/Wild', // Grapes
    'ing_02408': 'Citrus', // Oranges
    'ing_01607': 'Common & Core Staples', // Pears
    'ing_04211': 'Common & Core Staples', // Cranberries
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
        'ing_egg_whole_with_shell',
        'prey_mouse_pinky',
        'prey_mouse_adult',
        'prey_rat_pinky',
        'prey_rat_adult',
        'prey_chick_day_old',
        'prey_quail_whole',
        'prey_rabbit_whole',
        // Fruits & Vegetables Library
        'fruit_apple_peeled',
        'fruit_banana_whole_peel',
        'fruit_raspberries_fresh',
        'fruit_raspberries_dried',
        'fruit_blackberries_fresh',
        'fruit_blackberries_dried',
        'fruit_blueberries_dried',
        'fruit_strawberries_dried',
        'fruit_cranberries_dried',
        'fruit_watermelon_rind',
        'fruit_cantaloupe_flesh',
        'fruit_cantaloupe_rind',
        'fruit_honeydew_melon',
        'fruit_peach_pitted',
        'fruit_plum',
        'fruit_prune_dried',
        'fruit_nectarine_pitted',
        'fruit_cherry_pitted',
        'fruit_apricot',
        'fruit_papaya',
        'fruit_mango',
        'fruit_pineapple_fresh',
        'fruit_pineapple_pomace',
        'fruit_fig_fresh',
        'fruit_fig_dried',
        'fruit_date',
        'fruit_guava',
        'fruit_kiwi',
        'fruit_orange_pulp',
        'fruit_grapefruit',
        'fruit_tangerine_clementine',
        'fruit_raisins_dried',
        'fruit_persimmon',
        'fruit_pomegranate_arils',
        'veg_lettuce_leaf_red',
        'veg_lettuce_leaf_green',
        'veg_kale_curly',
        'veg_collard_greens',
        'veg_mustard_greens',
        'veg_turnip_greens',
        'veg_dandelion_greens',
        'veg_escarole_endive',
        'veg_swiss_chard',
        'veg_bok_choy',
        'veg_arugula',
        'veg_cabbage_green',
        'veg_cabbage_red',
        'veg_cabbage_savoy',
        'veg_beet_greens',
        'veg_carrots_shredded',
        'veg_carrots_dehydrated',
        'veg_sweet_potato_cooked',
        'veg_potato_cooked_flesh',
        'veg_potato_raw_green_sprouted',
        'veg_beets',
        'veg_turnips',
        'veg_rutabagas',
        'veg_radish_daikon',
        'veg_radish_red',
        'veg_parsnips',
        'veg_broccoli_florets',
        'veg_broccoli_stems',
        'veg_cauliflower',
        'veg_brussels_sprouts',
        'veg_pumpkin_canned_puree',
        'veg_butternut_squash',
        'veg_acorn_squash',
        'veg_yellow_summer_squash',
        'veg_bell_pepper_green',
        'veg_bell_pepper_red',
        'veg_bell_pepper_yellow',
        'veg_tomato_unripe_green_vine',
        'veg_green_beans',
        'veg_sugar_snap_peas',
        'veg_snow_peas',
        'veg_garden_peas',
        'veg_fennel',
        'veg_asparagus',
        'veg_rhubarb_stalk',
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
        final subCategory = _curatedUsdaSubCategoryOverrides[record['id']];
        _ingredients.add(Ingredient.fromUsdaJson(record, categoryOverride: category, subCategoryOverride: subCategory));
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
      // Whole egg blended with its own finely ground shell, as an alternative
      // to feeding the shell-off "Egg, whole, raw, fresh" (ing_03776) and a
      // separate calcium supplement. Estimated as ~89% egg content / ~11%
      // shell by weight (a chicken eggshell is commonly cited at roughly
      // 9-12% of total egg weight) and ~37% calcium as calcium carbonate for
      // the shell portion, blended against ing_03776's USDA SR Legacy values.
      // The shell must be dried and pulverized to a fine powder before
      // mixing in - coarse shell fragments are a choking/GI-injury risk.
      Ingredient(
        id: 'ing_egg_whole_with_shell',
        name: 'Egg, whole, raw, with finely ground shell',
        category: 'Proteins & Meal',
        catalogSource: 'USDA (est., shell blended in)',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 11.18,
          calciumPct: 4.12,
          phosphorusPct: 0.18,
          fatPct: 8.46,
          fiberPct: 0.0,
          energyKcalLb: 577.3,
          sodiumPct: 0.13,
          lysinePct: 0.24,
          methioninePct: 0.76,
          dryMatterPct: 32.0,
        ),
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

      // ===================================================================
      // Fruits & Vegetables Library
      // Hand-authored (the bundled USDA dump has no sugar field and can't
      // be bulk-queried for produce, per the curated-USDA allow-list above)
      // to cover the named subcategories a real feed-formulation library
      // uses: moisture/DM basis, sugar % (for the horse NSC/laminitis
      // caution wired in the safety rules), and item names deliberately
      // chosen so a keyword safety rule can target a risky variant (e.g.
      // raw/green potato skin, unripe tomato) without also flagging its
      // safe counterpart. The 22 pre-existing curated USDA Produce/Fruits
      // records above keep their real macro data untouched and only get a
      // subCategory retag (see _curatedUsdaSubCategoryOverrides).
      // ===================================================================

      // --- Fruits: Common & Core Staples ---
      Ingredient(
        id: 'fruit_apple_peeled',
        name: 'Apple (Peeled, No Seeds)',
        category: 'Fruits',
        subCategory: 'Common & Core Staples',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.3,
          calciumPct: 0.005,
          phosphorusPct: 0.007,
          fatPct: 0.1,
          fiberPct: 1.3,
          sugarPct: 10.0,
          energyKcalLb: 218,
          dryMatterPct: 14.4,
        ),
      ),
      Ingredient(
        id: 'fruit_banana_whole_peel',
        name: 'Banana (Whole, with Peel)',
        category: 'Fruits',
        subCategory: 'Common & Core Staples',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.5,
          calciumPct: 0.015,
          phosphorusPct: 0.03,
          fatPct: 0.3,
          fiberPct: 4.0,
          sugarPct: 9.0,
          energyKcalLb: 408,
          dryMatterPct: 30.0,
        ),
      ),
      Ingredient(
        id: 'fruit_raspberries_fresh',
        name: 'Raspberries (Fresh)',
        category: 'Fruits',
        subCategory: 'Common & Core Staples',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.2,
          calciumPct: 0.025,
          phosphorusPct: 0.029,
          fatPct: 0.65,
          fiberPct: 6.5,
          sugarPct: 4.4,
          energyKcalLb: 236,
          dryMatterPct: 14.2,
        ),
      ),
      Ingredient(
        id: 'fruit_raspberries_dried',
        name: 'Raspberries (Dried)',
        category: 'Fruits',
        subCategory: 'Common & Core Staples',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 5.0,
          calciumPct: 0.1,
          phosphorusPct: 0.12,
          fatPct: 3.0,
          fiberPct: 30.0,
          sugarPct: 30.0,
          energyKcalLb: 1406,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'fruit_blackberries_fresh',
        name: 'Blackberries (Fresh)',
        category: 'Fruits',
        subCategory: 'Common & Core Staples',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.4,
          calciumPct: 0.029,
          phosphorusPct: 0.022,
          fatPct: 0.5,
          fiberPct: 5.3,
          sugarPct: 4.9,
          energyKcalLb: 195,
          dryMatterPct: 11.8,
        ),
      ),
      Ingredient(
        id: 'fruit_blackberries_dried',
        name: 'Blackberries (Dried)',
        category: 'Fruits',
        subCategory: 'Common & Core Staples',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 6.0,
          calciumPct: 0.12,
          phosphorusPct: 0.1,
          fatPct: 3.0,
          fiberPct: 30.0,
          sugarPct: 30.0,
          energyKcalLb: 1361,
          dryMatterPct: 88.0,
        ),
      ),
      Ingredient(
        id: 'fruit_blueberries_dried',
        name: 'Blueberries (Dried)',
        category: 'Fruits',
        subCategory: 'Common & Core Staples',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.8,
          calciumPct: 0.034,
          phosphorusPct: 0.04,
          fatPct: 1.6,
          fiberPct: 11.0,
          sugarPct: 60.0,
          energyKcalLb: 1438,
          dryMatterPct: 85.0,
        ),
      ),
      Ingredient(
        id: 'fruit_strawberries_dried',
        name: 'Strawberries (Dried)',
        category: 'Fruits',
        subCategory: 'Common & Core Staples',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 4.0,
          calciumPct: 0.035,
          phosphorusPct: 0.07,
          fatPct: 1.0,
          fiberPct: 9.0,
          sugarPct: 55.0,
          energyKcalLb: 1542,
          dryMatterPct: 90.0,
        ),
      ),
      Ingredient(
        id: 'fruit_cranberries_dried',
        name: 'Cranberries (Dried, Sweetened)',
        category: 'Fruits',
        subCategory: 'Common & Core Staples',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.15,
          calciumPct: 0.009,
          phosphorusPct: 0.012,
          fatPct: 1.1,
          fiberPct: 5.7,
          sugarPct: 65.0,
          energyKcalLb: 1474,
          dryMatterPct: 85.0,
        ),
      ),

      // --- Fruits: Melons & High-Moisture ---
      Ingredient(
        id: 'fruit_watermelon_rind',
        name: 'Watermelon Rind',
        category: 'Fruits',
        subCategory: 'Melons & High-Moisture',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.6,
          calciumPct: 0.007,
          phosphorusPct: 0.01,
          fatPct: 0.2,
          fiberPct: 0.5,
          sugarPct: 2.0,
          energyKcalLb: 82,
          dryMatterPct: 7.0,
        ),
      ),
      Ingredient(
        id: 'fruit_cantaloupe_flesh',
        name: 'Cantaloupe (Flesh)',
        category: 'Fruits',
        subCategory: 'Melons & High-Moisture',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.84,
          calciumPct: 0.009,
          phosphorusPct: 0.015,
          fatPct: 0.19,
          fiberPct: 0.9,
          sugarPct: 7.9,
          energyKcalLb: 154,
          dryMatterPct: 9.8,
        ),
      ),
      Ingredient(
        id: 'fruit_cantaloupe_rind',
        name: 'Cantaloupe Rind',
        category: 'Fruits',
        subCategory: 'Melons & High-Moisture',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.7,
          calciumPct: 0.01,
          phosphorusPct: 0.012,
          fatPct: 0.1,
          fiberPct: 1.5,
          sugarPct: 2.0,
          energyKcalLb: 91,
          dryMatterPct: 7.0,
        ),
      ),
      Ingredient(
        id: 'fruit_honeydew_melon',
        name: 'Honeydew Melon',
        category: 'Fruits',
        subCategory: 'Melons & High-Moisture',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.54,
          calciumPct: 0.006,
          phosphorusPct: 0.011,
          fatPct: 0.14,
          fiberPct: 0.8,
          sugarPct: 8.1,
          energyKcalLb: 163,
          dryMatterPct: 10.2,
        ),
      ),

      // --- Fruits: Stone Fruits & Tree Fruits ---
      // Names deliberately include "Pitted" as real-world prep guidance;
      // the pit/seed-removal reminder safety rule (Phase 4) still fires on
      // these, the same way nitrate-forage advisories fire on the plain
      // ingredient regardless of catalog labeling.
      Ingredient(
        id: 'fruit_peach_pitted',
        name: 'Peach (Pitted, Flesh)',
        category: 'Fruits',
        subCategory: 'Stone Fruits & Tree Fruits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.91,
          calciumPct: 0.006,
          phosphorusPct: 0.02,
          fatPct: 0.25,
          fiberPct: 1.5,
          sugarPct: 8.4,
          energyKcalLb: 177,
          dryMatterPct: 11.1,
        ),
      ),
      Ingredient(
        id: 'fruit_plum',
        name: 'Plum (Pitted, Flesh)',
        category: 'Fruits',
        subCategory: 'Stone Fruits & Tree Fruits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.7,
          calciumPct: 0.006,
          phosphorusPct: 0.016,
          fatPct: 0.28,
          fiberPct: 1.4,
          sugarPct: 9.9,
          energyKcalLb: 209,
          dryMatterPct: 12.8,
        ),
      ),
      Ingredient(
        // Named to avoid the "plum" pit-reminder keyword - prunes are
        // commercially dried already pitted, so the fresh-fruit pit
        // reminder shouldn't fire on this item.
        id: 'fruit_prune_dried',
        name: 'Prune (Dried, Pitted)',
        category: 'Fruits',
        subCategory: 'Stone Fruits & Tree Fruits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.18,
          calciumPct: 0.043,
          phosphorusPct: 0.069,
          fatPct: 0.38,
          fiberPct: 7.1,
          sugarPct: 38.1,
          energyKcalLb: 1089,
          dryMatterPct: 69.1,
        ),
      ),
      Ingredient(
        id: 'fruit_nectarine_pitted',
        name: 'Nectarine (Pitted, Flesh)',
        category: 'Fruits',
        subCategory: 'Stone Fruits & Tree Fruits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.06,
          calciumPct: 0.006,
          phosphorusPct: 0.026,
          fatPct: 0.32,
          fiberPct: 1.7,
          sugarPct: 7.9,
          energyKcalLb: 200,
          dryMatterPct: 12.4,
        ),
      ),
      Ingredient(
        id: 'fruit_cherry_pitted',
        name: 'Cherry (Pitted, Flesh)',
        category: 'Fruits',
        subCategory: 'Stone Fruits & Tree Fruits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.06,
          calciumPct: 0.013,
          phosphorusPct: 0.021,
          fatPct: 0.2,
          fiberPct: 2.1,
          sugarPct: 12.8,
          energyKcalLb: 286,
          dryMatterPct: 17.7,
        ),
      ),
      Ingredient(
        id: 'fruit_apricot',
        name: 'Apricot (Pitted, Flesh)',
        category: 'Fruits',
        subCategory: 'Stone Fruits & Tree Fruits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.4,
          calciumPct: 0.013,
          phosphorusPct: 0.023,
          fatPct: 0.39,
          fiberPct: 2.0,
          sugarPct: 9.2,
          energyKcalLb: 218,
          dryMatterPct: 13.6,
        ),
      ),

      // --- Fruits: Tropical & Exotic ---
      Ingredient(
        id: 'fruit_papaya',
        name: 'Papaya',
        category: 'Fruits',
        subCategory: 'Tropical & Exotic',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.47,
          calciumPct: 0.02,
          phosphorusPct: 0.01,
          fatPct: 0.26,
          fiberPct: 1.7,
          sugarPct: 7.8,
          energyKcalLb: 195,
          dryMatterPct: 12.0,
        ),
      ),
      Ingredient(
        id: 'fruit_mango',
        name: 'Mango',
        category: 'Fruits',
        subCategory: 'Tropical & Exotic',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.82,
          calciumPct: 0.011,
          phosphorusPct: 0.014,
          fatPct: 0.38,
          fiberPct: 1.6,
          sugarPct: 13.7,
          energyKcalLb: 272,
          dryMatterPct: 16.5,
        ),
      ),
      Ingredient(
        id: 'fruit_pineapple_fresh',
        name: 'Pineapple (Fresh)',
        category: 'Fruits',
        subCategory: 'Tropical & Exotic',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.54,
          calciumPct: 0.013,
          phosphorusPct: 0.008,
          fatPct: 0.12,
          fiberPct: 1.4,
          sugarPct: 9.9,
          energyKcalLb: 227,
          dryMatterPct: 14.0,
        ),
      ),
      Ingredient(
        id: 'fruit_pineapple_pomace',
        name: 'Pineapple Pomace',
        category: 'Fruits',
        subCategory: 'Tropical & Exotic',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 3.0,
          calciumPct: 0.015,
          phosphorusPct: 0.01,
          fatPct: 0.5,
          fiberPct: 4.0,
          sugarPct: 5.0,
          energyKcalLb: 204,
          dryMatterPct: 20.0,
        ),
      ),
      Ingredient(
        id: 'fruit_fig_fresh',
        name: 'Fig (Fresh)',
        category: 'Fruits',
        subCategory: 'Tropical & Exotic',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.75,
          calciumPct: 0.035,
          phosphorusPct: 0.014,
          fatPct: 0.3,
          fiberPct: 2.9,
          sugarPct: 16.3,
          energyKcalLb: 336,
          dryMatterPct: 20.9,
        ),
      ),
      Ingredient(
        id: 'fruit_fig_dried',
        name: 'Fig (Dried)',
        category: 'Fruits',
        subCategory: 'Tropical & Exotic',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 3.3,
          calciumPct: 0.162,
          phosphorusPct: 0.067,
          fatPct: 0.93,
          fiberPct: 9.8,
          sugarPct: 47.9,
          energyKcalLb: 1130,
          dryMatterPct: 69.6,
        ),
      ),
      Ingredient(
        id: 'fruit_date',
        name: 'Date (Dried, Pitted)',
        category: 'Fruits',
        subCategory: 'Tropical & Exotic',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.81,
          calciumPct: 0.064,
          phosphorusPct: 0.062,
          fatPct: 0.15,
          fiberPct: 6.7,
          sugarPct: 66.5,
          energyKcalLb: 1257,
          dryMatterPct: 78.7,
        ),
      ),
      Ingredient(
        id: 'fruit_guava',
        name: 'Guava',
        category: 'Fruits',
        subCategory: 'Tropical & Exotic',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.55,
          calciumPct: 0.018,
          phosphorusPct: 0.04,
          fatPct: 0.95,
          fiberPct: 5.4,
          sugarPct: 8.9,
          energyKcalLb: 308,
          dryMatterPct: 19.2,
        ),
      ),
      Ingredient(
        id: 'fruit_kiwi',
        name: 'Kiwi',
        category: 'Fruits',
        subCategory: 'Tropical & Exotic',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.14,
          calciumPct: 0.034,
          phosphorusPct: 0.034,
          fatPct: 0.52,
          fiberPct: 3.0,
          sugarPct: 9.0,
          energyKcalLb: 277,
          dryMatterPct: 16.9,
        ),
      ),

      // --- Fruits: Citrus ---
      Ingredient(
        id: 'fruit_orange_pulp',
        name: 'Orange (Peeled, Pulp Only)',
        category: 'Fruits',
        subCategory: 'Citrus',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.94,
          calciumPct: 0.04,
          phosphorusPct: 0.014,
          fatPct: 0.12,
          fiberPct: 2.4,
          sugarPct: 9.4,
          energyKcalLb: 213,
          dryMatterPct: 13.2,
        ),
      ),
      Ingredient(
        id: 'fruit_grapefruit',
        name: 'Grapefruit',
        category: 'Fruits',
        subCategory: 'Citrus',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.77,
          calciumPct: 0.022,
          phosphorusPct: 0.008,
          fatPct: 0.14,
          fiberPct: 1.6,
          sugarPct: 6.89,
          energyKcalLb: 191,
          dryMatterPct: 11.94,
        ),
      ),
      Ingredient(
        id: 'fruit_tangerine_clementine',
        name: 'Tangerine / Clementine',
        category: 'Fruits',
        subCategory: 'Citrus',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.81,
          calciumPct: 0.037,
          phosphorusPct: 0.02,
          fatPct: 0.31,
          fiberPct: 1.7,
          sugarPct: 10.6,
          energyKcalLb: 240,
          dryMatterPct: 14.8,
        ),
      ),

      // --- Fruits: Specialty/Wild ---
      Ingredient(
        // Named to isolate the "raisin" toxicity keyword from "grapes"
        // (both trigger the canine grape-toxicity rules, separately).
        id: 'fruit_raisins_dried',
        name: 'Raisins (Dried Grapes)',
        category: 'Fruits',
        subCategory: 'Specialty/Wild',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 3.07,
          calciumPct: 0.05,
          phosphorusPct: 0.101,
          fatPct: 0.46,
          fiberPct: 3.7,
          sugarPct: 59.2,
          energyKcalLb: 1356,
          dryMatterPct: 84.6,
        ),
      ),
      Ingredient(
        id: 'fruit_persimmon',
        name: 'Persimmon',
        category: 'Fruits',
        subCategory: 'Specialty/Wild',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.58,
          calciumPct: 0.008,
          phosphorusPct: 0.017,
          fatPct: 0.19,
          fiberPct: 3.6,
          sugarPct: 12.5,
          energyKcalLb: 318,
          dryMatterPct: 19.7,
        ),
      ),
      Ingredient(
        id: 'fruit_pomegranate_arils',
        name: 'Pomegranate (Arils)',
        category: 'Fruits',
        subCategory: 'Specialty/Wild',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.67,
          calciumPct: 0.01,
          phosphorusPct: 0.036,
          fatPct: 1.17,
          fiberPct: 4.0,
          sugarPct: 13.7,
          energyKcalLb: 377,
          dryMatterPct: 22.1,
        ),
      ),

      // --- Vegetables: Leafy Greens & Forage Produce ---
      Ingredient(
        id: 'veg_lettuce_leaf_red',
        name: 'Leaf Lettuce (Red)',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.33,
          calciumPct: 0.033,
          phosphorusPct: 0.027,
          fatPct: 0.22,
          fiberPct: 0.9,
          sugarPct: 0.94,
          energyKcalLb: 73,
          dryMatterPct: 4.4,
        ),
      ),
      Ingredient(
        id: 'veg_lettuce_leaf_green',
        name: 'Leaf Lettuce (Green)',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.36,
          calciumPct: 0.036,
          phosphorusPct: 0.029,
          fatPct: 0.15,
          fiberPct: 1.3,
          sugarPct: 0.78,
          energyKcalLb: 68,
          dryMatterPct: 5.4,
        ),
      ),
      Ingredient(
        id: 'veg_kale_curly',
        name: 'Kale (Curly/Lacinato)',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 4.28,
          calciumPct: 0.15,
          phosphorusPct: 0.055,
          fatPct: 0.93,
          fiberPct: 3.6,
          sugarPct: 2.26,
          energyKcalLb: 222,
          dryMatterPct: 16.0,
        ),
      ),
      Ingredient(
        id: 'veg_collard_greens',
        name: 'Collard Greens',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 3.0,
          calciumPct: 0.232,
          phosphorusPct: 0.025,
          fatPct: 0.61,
          fiberPct: 4.0,
          sugarPct: 0.5,
          energyKcalLb: 145,
          dryMatterPct: 10.4,
        ),
      ),
      Ingredient(
        id: 'veg_mustard_greens',
        name: 'Mustard Greens',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.86,
          calciumPct: 0.103,
          phosphorusPct: 0.048,
          fatPct: 0.42,
          fiberPct: 3.2,
          sugarPct: 1.32,
          energyKcalLb: 123,
          dryMatterPct: 9.2,
        ),
      ),
      Ingredient(
        id: 'veg_turnip_greens',
        name: 'Turnip Greens',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.5,
          calciumPct: 0.19,
          phosphorusPct: 0.042,
          fatPct: 0.3,
          fiberPct: 3.2,
          sugarPct: 0.81,
          energyKcalLb: 145,
          dryMatterPct: 10.3,
        ),
      ),
      Ingredient(
        id: 'veg_dandelion_greens',
        name: 'Dandelion Greens',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.7,
          calciumPct: 0.187,
          phosphorusPct: 0.066,
          fatPct: 0.7,
          fiberPct: 3.5,
          sugarPct: 0.71,
          energyKcalLb: 204,
          dryMatterPct: 14.4,
        ),
      ),
      Ingredient(
        id: 'veg_escarole_endive',
        name: 'Escarole / Endive',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.25,
          calciumPct: 0.052,
          phosphorusPct: 0.028,
          fatPct: 0.2,
          fiberPct: 3.1,
          sugarPct: 0.25,
          energyKcalLb: 77,
          dryMatterPct: 6.2,
        ),
      ),
      Ingredient(
        // Chard is a genuinely high-oxalate green (unlike most other new
        // leafy greens here), so it gets a real oxalatePct - this feeds
        // the existing Ca:Oxalate ratio safety check directly.
        id: 'veg_swiss_chard',
        name: 'Swiss Chard',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.8,
          calciumPct: 0.051,
          phosphorusPct: 0.046,
          fatPct: 0.2,
          fiberPct: 1.6,
          sugarPct: 1.1,
          oxalatePct: 0.65,
          energyKcalLb: 86,
          dryMatterPct: 7.3,
        ),
      ),
      Ingredient(
        id: 'veg_bok_choy',
        name: 'Bok Choy / Pak Choy',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.5,
          calciumPct: 0.105,
          phosphorusPct: 0.037,
          fatPct: 0.2,
          fiberPct: 1.0,
          sugarPct: 1.18,
          energyKcalLb: 59,
          dryMatterPct: 4.7,
        ),
      ),
      Ingredient(
        id: 'veg_arugula',
        name: 'Arugula / Rocket',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.58,
          calciumPct: 0.16,
          phosphorusPct: 0.052,
          fatPct: 0.66,
          fiberPct: 1.6,
          sugarPct: 2.05,
          energyKcalLb: 113,
          dryMatterPct: 8.3,
        ),
      ),
      Ingredient(
        id: 'veg_cabbage_green',
        name: 'Cabbage (Green)',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.28,
          calciumPct: 0.04,
          phosphorusPct: 0.026,
          fatPct: 0.1,
          fiberPct: 2.5,
          sugarPct: 3.2,
          energyKcalLb: 113,
          dryMatterPct: 7.8,
        ),
      ),
      Ingredient(
        id: 'veg_cabbage_red',
        name: 'Cabbage (Red)',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.43,
          calciumPct: 0.045,
          phosphorusPct: 0.03,
          fatPct: 0.16,
          fiberPct: 2.1,
          sugarPct: 3.83,
          energyKcalLb: 141,
          dryMatterPct: 9.6,
        ),
      ),
      Ingredient(
        id: 'veg_cabbage_savoy',
        name: 'Cabbage (Savoy)',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.0,
          calciumPct: 0.035,
          phosphorusPct: 0.042,
          fatPct: 0.1,
          fiberPct: 3.1,
          sugarPct: 2.3,
          energyKcalLb: 123,
          dryMatterPct: 9.0,
        ),
      ),
      Ingredient(
        // Also a genuinely high-oxalate green, same rationale as chard.
        id: 'veg_beet_greens',
        name: 'Beet Greens',
        category: 'Produce',
        subCategory: 'Leafy Greens & Forage Produce',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.2,
          calciumPct: 0.117,
          phosphorusPct: 0.041,
          fatPct: 0.13,
          fiberPct: 3.7,
          sugarPct: 0.5,
          oxalatePct: 0.6,
          energyKcalLb: 100,
          dryMatterPct: 8.6,
        ),
      ),

      // --- Vegetables: Root Vegetables & Tubers ---
      Ingredient(
        id: 'veg_carrots_shredded',
        name: 'Carrots (Shredded)',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.93,
          calciumPct: 0.033,
          phosphorusPct: 0.035,
          fatPct: 0.24,
          fiberPct: 2.8,
          sugarPct: 4.7,
          energyKcalLb: 186,
          dryMatterPct: 11.7,
        ),
      ),
      Ingredient(
        id: 'veg_carrots_dehydrated',
        name: 'Carrots (Dehydrated)',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 7.0,
          calciumPct: 0.25,
          phosphorusPct: 0.26,
          fatPct: 1.8,
          fiberPct: 20.0,
          sugarPct: 35.0,
          energyKcalLb: 1542,
          dryMatterPct: 96.0,
        ),
      ),
      Ingredient(
        id: 'veg_sweet_potato_cooked',
        name: 'Sweet Potato / Yam (Cooked)',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.0,
          calciumPct: 0.03,
          phosphorusPct: 0.047,
          fatPct: 0.15,
          fiberPct: 3.3,
          sugarPct: 6.5,
          energyKcalLb: 408,
          dryMatterPct: 23.8,
        ),
      ),
      Ingredient(
        // The safe form - cooked, peeled flesh only.
        id: 'veg_potato_cooked_flesh',
        name: 'Potato (Cooked, Peeled Flesh)',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.87,
          calciumPct: 0.005,
          phosphorusPct: 0.044,
          fatPct: 0.1,
          fiberPct: 1.8,
          sugarPct: 0.8,
          energyKcalLb: 395,
          dryMatterPct: 23.0,
        ),
      ),
      Ingredient(
        // Named to isolate the solanine safety-rule keyword from the safe
        // cooked-flesh item above - raw skin/green/sprouted potato is the
        // genuinely risky form (solanine concentrates in the skin and any
        // green coloring).
        id: 'veg_potato_raw_green_sprouted',
        name: 'Potato (Raw, Green/Sprouted Skin)',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.0,
          calciumPct: 0.012,
          phosphorusPct: 0.057,
          fatPct: 0.1,
          fiberPct: 2.2,
          sugarPct: 0.8,
          energyKcalLb: 349,
          dryMatterPct: 21.0,
        ),
      ),
      Ingredient(
        id: 'veg_beets',
        name: 'Beets',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.61,
          calciumPct: 0.016,
          phosphorusPct: 0.04,
          fatPct: 0.17,
          fiberPct: 2.8,
          sugarPct: 6.76,
          energyKcalLb: 195,
          dryMatterPct: 12.4,
        ),
      ),
      Ingredient(
        id: 'veg_turnips',
        name: 'Turnips',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.9,
          calciumPct: 0.03,
          phosphorusPct: 0.027,
          fatPct: 0.1,
          fiberPct: 1.8,
          sugarPct: 3.8,
          energyKcalLb: 127,
          dryMatterPct: 8.1,
        ),
      ),
      Ingredient(
        id: 'veg_rutabagas',
        name: 'Rutabagas',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.08,
          calciumPct: 0.043,
          phosphorusPct: 0.058,
          fatPct: 0.16,
          fiberPct: 2.3,
          sugarPct: 4.46,
          energyKcalLb: 168,
          dryMatterPct: 10.3,
        ),
      ),
      Ingredient(
        id: 'veg_radish_daikon',
        name: 'Radish (Daikon)',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.6,
          calciumPct: 0.027,
          phosphorusPct: 0.022,
          fatPct: 0.1,
          fiberPct: 1.6,
          sugarPct: 2.5,
          energyKcalLb: 82,
          dryMatterPct: 5.4,
        ),
      ),
      Ingredient(
        id: 'veg_radish_red',
        name: 'Radish (Red)',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.68,
          calciumPct: 0.025,
          phosphorusPct: 0.02,
          fatPct: 0.1,
          fiberPct: 1.6,
          sugarPct: 1.86,
          energyKcalLb: 73,
          dryMatterPct: 4.7,
        ),
      ),
      Ingredient(
        id: 'veg_parsnips',
        name: 'Parsnips',
        category: 'Produce',
        subCategory: 'Root Vegetables & Tubers',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.2,
          calciumPct: 0.036,
          phosphorusPct: 0.071,
          fatPct: 0.3,
          fiberPct: 4.9,
          sugarPct: 4.8,
          energyKcalLb: 340,
          dryMatterPct: 20.5,
        ),
      ),

      // --- Vegetables: Cruciferous ---
      Ingredient(
        id: 'veg_broccoli_florets',
        name: 'Broccoli (Florets)',
        category: 'Produce',
        subCategory: 'Cruciferous',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.82,
          calciumPct: 0.047,
          phosphorusPct: 0.066,
          fatPct: 0.37,
          fiberPct: 2.6,
          sugarPct: 1.7,
          energyKcalLb: 154,
          dryMatterPct: 10.7,
        ),
      ),
      Ingredient(
        id: 'veg_broccoli_stems',
        name: 'Broccoli (Stems)',
        category: 'Produce',
        subCategory: 'Cruciferous',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.9,
          calciumPct: 0.04,
          phosphorusPct: 0.05,
          fatPct: 0.2,
          fiberPct: 3.0,
          sugarPct: 1.5,
          energyKcalLb: 127,
          dryMatterPct: 9.3,
        ),
      ),
      Ingredient(
        id: 'veg_cauliflower',
        name: 'Cauliflower',
        category: 'Produce',
        subCategory: 'Cruciferous',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.92,
          calciumPct: 0.022,
          phosphorusPct: 0.044,
          fatPct: 0.28,
          fiberPct: 2.0,
          sugarPct: 1.91,
          energyKcalLb: 113,
          dryMatterPct: 8.0,
        ),
      ),
      Ingredient(
        id: 'veg_brussels_sprouts',
        name: 'Brussels Sprouts',
        category: 'Produce',
        subCategory: 'Cruciferous',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 3.38,
          calciumPct: 0.042,
          phosphorusPct: 0.069,
          fatPct: 0.3,
          fiberPct: 3.8,
          sugarPct: 2.2,
          energyKcalLb: 195,
          dryMatterPct: 14.0,
        ),
      ),

      // --- Vegetables: Squash & Cucurbits ---
      Ingredient(
        id: 'veg_pumpkin_canned_puree',
        name: 'Pumpkin (Canned Puree)',
        category: 'Produce',
        subCategory: 'Squash & Cucurbits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.1,
          calciumPct: 0.015,
          phosphorusPct: 0.034,
          fatPct: 0.28,
          fiberPct: 3.0,
          sugarPct: 3.0,
          energyKcalLb: 154,
          dryMatterPct: 9.5,
        ),
      ),
      Ingredient(
        id: 'veg_butternut_squash',
        name: 'Butternut Squash',
        category: 'Produce',
        subCategory: 'Squash & Cucurbits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.0,
          calciumPct: 0.048,
          phosphorusPct: 0.033,
          fatPct: 0.1,
          fiberPct: 2.0,
          sugarPct: 2.2,
          energyKcalLb: 204,
          dryMatterPct: 13.6,
        ),
      ),
      Ingredient(
        id: 'veg_acorn_squash',
        name: 'Acorn Squash',
        category: 'Produce',
        subCategory: 'Squash & Cucurbits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.8,
          calciumPct: 0.033,
          phosphorusPct: 0.033,
          fatPct: 0.1,
          fiberPct: 1.9,
          sugarPct: 1.5,
          energyKcalLb: 181,
          dryMatterPct: 12.2,
        ),
      ),
      Ingredient(
        id: 'veg_yellow_summer_squash',
        name: 'Yellow Summer Squash',
        category: 'Produce',
        subCategory: 'Squash & Cucurbits',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.21,
          calciumPct: 0.015,
          phosphorusPct: 0.038,
          fatPct: 0.18,
          fiberPct: 1.1,
          sugarPct: 2.5,
          energyKcalLb: 73,
          dryMatterPct: 5.4,
        ),
      ),

      // --- Vegetables: Fruiting Vegetables & Nightshades ---
      Ingredient(
        id: 'veg_bell_pepper_green',
        name: 'Bell Pepper (Green)',
        category: 'Produce',
        subCategory: 'Fruiting Vegetables & Nightshades',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.86,
          calciumPct: 0.01,
          phosphorusPct: 0.02,
          fatPct: 0.17,
          fiberPct: 1.7,
          sugarPct: 2.4,
          energyKcalLb: 91,
          dryMatterPct: 6.1,
        ),
      ),
      Ingredient(
        id: 'veg_bell_pepper_red',
        name: 'Bell Pepper (Red)',
        category: 'Produce',
        subCategory: 'Fruiting Vegetables & Nightshades',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.0,
          calciumPct: 0.007,
          phosphorusPct: 0.026,
          fatPct: 0.3,
          fiberPct: 2.1,
          sugarPct: 4.2,
          energyKcalLb: 141,
          dryMatterPct: 8.0,
        ),
      ),
      Ingredient(
        id: 'veg_bell_pepper_yellow',
        name: 'Bell Pepper (Yellow)',
        category: 'Produce',
        subCategory: 'Fruiting Vegetables & Nightshades',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.0,
          calciumPct: 0.011,
          phosphorusPct: 0.024,
          fatPct: 0.2,
          fiberPct: 0.9,
          sugarPct: 3.6,
          energyKcalLb: 123,
          dryMatterPct: 8.0,
        ),
      ),
      Ingredient(
        // Named to isolate the solanine/unripe-nightshade safety-rule
        // keyword from ordinary ripe tomato (which has no such caution).
        id: 'veg_tomato_unripe_green_vine',
        name: 'Tomato (Unripe/Green, Vine)',
        category: 'Produce',
        subCategory: 'Fruiting Vegetables & Nightshades',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.2,
          calciumPct: 0.008,
          phosphorusPct: 0.027,
          fatPct: 0.2,
          fiberPct: 1.2,
          sugarPct: 2.0,
          energyKcalLb: 104,
          dryMatterPct: 7.0,
        ),
      ),
      Ingredient(
        id: 'veg_green_beans',
        name: 'Green Beans / Snap Beans',
        category: 'Produce',
        subCategory: 'Fruiting Vegetables & Nightshades',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.83,
          calciumPct: 0.037,
          phosphorusPct: 0.038,
          fatPct: 0.22,
          fiberPct: 2.7,
          sugarPct: 3.26,
          energyKcalLb: 141,
          dryMatterPct: 9.7,
        ),
      ),
      Ingredient(
        id: 'veg_sugar_snap_peas',
        name: 'Sugar Snap Peas',
        category: 'Produce',
        subCategory: 'Fruiting Vegetables & Nightshades',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.8,
          calciumPct: 0.043,
          phosphorusPct: 0.053,
          fatPct: 0.2,
          fiberPct: 2.6,
          sugarPct: 4.0,
          energyKcalLb: 191,
          dryMatterPct: 11.1,
        ),
      ),
      Ingredient(
        id: 'veg_snow_peas',
        name: 'Snow Peas',
        category: 'Produce',
        subCategory: 'Fruiting Vegetables & Nightshades',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.8,
          calciumPct: 0.043,
          phosphorusPct: 0.053,
          fatPct: 0.2,
          fiberPct: 2.6,
          sugarPct: 4.0,
          energyKcalLb: 191,
          dryMatterPct: 11.1,
        ),
      ),
      Ingredient(
        id: 'veg_garden_peas',
        name: 'Garden Peas',
        category: 'Produce',
        subCategory: 'Fruiting Vegetables & Nightshades',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 5.42,
          calciumPct: 0.025,
          phosphorusPct: 0.108,
          fatPct: 0.4,
          fiberPct: 5.7,
          sugarPct: 5.67,
          energyKcalLb: 367,
          dryMatterPct: 21.1,
        ),
      ),

      // --- Vegetables: Stalk & Bulb ---
      Ingredient(
        id: 'veg_fennel',
        name: 'Fennel (Bulb)',
        category: 'Produce',
        subCategory: 'Stalk & Bulb',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 1.24,
          calciumPct: 0.049,
          phosphorusPct: 0.05,
          fatPct: 0.2,
          fiberPct: 3.1,
          sugarPct: 3.9,
          energyKcalLb: 141,
          dryMatterPct: 9.8,
        ),
      ),
      Ingredient(
        id: 'veg_asparagus',
        name: 'Asparagus',
        category: 'Produce',
        subCategory: 'Stalk & Bulb',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 2.2,
          calciumPct: 0.024,
          phosphorusPct: 0.052,
          fatPct: 0.12,
          fiberPct: 2.1,
          sugarPct: 1.88,
          energyKcalLb: 91,
          dryMatterPct: 6.8,
        ),
      ),
      Ingredient(
        // Stalk only, by design - the leaf blade is genuinely toxic
        // (much higher oxalate than the stalk) and isn't modeled here as
        // an ingredient since it's never meant to be fed; see the
        // rhubarb-leaf advisory safety rule (Phase 4) instead.
        id: 'veg_rhubarb_stalk',
        name: 'Rhubarb (Stalk Only)',
        category: 'Produce',
        subCategory: 'Stalk & Bulb',
        asFedMetrics: AsFedMetrics(
          crudeProteinPct: 0.9,
          calciumPct: 0.086,
          phosphorusPct: 0.014,
          fatPct: 0.2,
          fiberPct: 1.8,
          sugarPct: 1.1,
          oxalatePct: 0.5,
          energyKcalLb: 95,
          dryMatterPct: 6.4,
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