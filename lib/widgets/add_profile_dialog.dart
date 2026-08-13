import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/animal_profile.dart';
import '../models/species_catalog.dart';
import '../services/database_service.dart';
import '../services/tier_service.dart';
import 'upgrade_dialog.dart';

class AddProfileDialog extends StatefulWidget {
  final Function(AnimalProfile) onProfileSaved;
  final AnimalProfile? profileToEdit;

  const AddProfileDialog({
    super.key,
    required this.onProfileSaved,
    this.profileToEdit,
  });

  @override
  State<AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<AddProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _headCountController;

  late List<SpeciesCategory> _catalog;
  late String _selectedCategory;
  late String _selectedSubgroup;
  late String _selectedSpecies;
  late String _selectedEnvironment;
  late String _selectedProductionStage;
  late String _selectedSex;
  late String _selectedAgeGroup;
  late String _selectedFeedingSystem;
  bool _initialized = false;

  final List<String> _sexes = ['Unknown', 'Male', 'Female', 'Mixed'];
  final List<String> _ageGroups = ['Baby', 'Juvenile', 'Adult', 'Geriatric'];
  final List<String> _environments = ['Outdoor', 'Indoor', 'Hybrid / Pasture'];
  final List<String> _feedingSystems = [
    'Total Mixed Ration (TMR)',
    'Pasture / Forage-First',
    'Free-Choice Grain + Supplement',
    'Raw / Whole Food + Premix',
    'Whole Prey / Feeder Animals',
  ];
  final List<String> _productionStages = [
    'Healthy / Normal',
    'Active Layer',
    'Breeder / Production',
    'Working / Performance',
    'Molting / Recovery',
    'Lactating / Nursing',
    'Breeder / High Output',
    'Growth Boost / Juvenile',
  ];

  static const Set<String> _lockedProductionStages = {
    'Molting / Recovery',
    'Lactating / Nursing',
    'Breeder / High Output',
    'Growth Boost / Juvenile',
  };

  static const _feedingSystemLabels = {
    'Total Mixed Ration (TMR)': 'Total Mixed Ration (Your Pantry Items Only)',
    'Pasture / Forage-First': 'Pasture / Forage-First (mostly grazing; feed fills the gap)',
    'Free-Choice Grain + Supplement': 'Free-Choice Grain + Supplement (offered separately; animal self-regulates)',
    'Raw / Whole Food + Premix': 'Raw / Whole Food + Premix (fresh ingredients + a vitamin/mineral premix)',
    'Whole Prey / Feeder Animals': 'Whole Prey / Feeder Animals (e.g. reptiles fed whole prey)',
  };

  @override
  void initState() {
    super.initState();
    final edit = widget.profileToEdit;

    _nameController = TextEditingController(text: edit?.name ?? '');
    _headCountController = TextEditingController(text: edit?.headCount.toString() ?? '1');

    _selectedEnvironment = edit?.environment ?? 'Outdoor';
    _selectedProductionStage = edit?.productionStage ?? 'Healthy / Normal';
    if (!_productionStages.contains(_selectedProductionStage)) {
      _productionStages.add(_selectedProductionStage);
    }
    _selectedSex = edit?.sex ?? 'Unknown';
    _selectedAgeGroup = edit?.ageGroup ?? 'Adult';
    _selectedFeedingSystem = edit?.feedingSystem ?? 'Total Mixed Ration (TMR)';
  }

  /// Default a brand-new profile to Dog: most users adding their first
  /// animal or flock profile own a dog or cat, so Dog (Companion Mammals)
  /// saves the common case a few taps instead of landing on an arbitrary
  /// first catalog entry.
  void _selectDefaultSpecies() {
    for (final category in _catalog) {
      for (final subgroup in category.subgroups) {
        if (subgroup.species.contains('Dog')) {
          _selectedCategory = category.name;
          _selectedSubgroup = subgroup.name;
          _selectedSpecies = 'Dog';
          return;
        }
      }
    }
    _selectedCategory = _catalog.first.name;
    _selectedSubgroup = _catalog.first.subgroups.first.name;
    _selectedSpecies = _catalog.first.subgroups.first.species.first;
  }

  void _initFromCatalog(List<SpeciesCategory> catalog) {
    if (_initialized || catalog.isEmpty) return;
    _initialized = true;
    _catalog = catalog;

    _selectDefaultSpecies();

    final edit = widget.profileToEdit;
    if (edit == null || !edit.species.contains(': ')) return;

    final parts = edit.species.split(': ');
    final categoryName = parts[0];
    final speciesName = parts.sublist(1).join(': ');

    // Exact match first.
    for (final category in catalog) {
      if (category.name != categoryName) continue;
      for (final subgroup in category.subgroups) {
        if (subgroup.species.contains(speciesName)) {
          _selectedCategory = category.name;
          _selectedSubgroup = subgroup.name;
          _selectedSpecies = speciesName;
          return;
        }
      }
    }

    // Fuzzy fallback: the species list has grown/changed since some profiles
    // were created (e.g. old "Poultry (Chicken)" vs. the new breed-specific
    // entries) - try to land on something similarly named instead of
    // silently jumping to an unrelated default when editing an older profile.
    final keyword = RegExp(r'\(([^)]+)\)').firstMatch(speciesName)?.group(1)?.toLowerCase() ?? speciesName.toLowerCase();
    for (final category in catalog) {
      for (final subgroup in category.subgroups) {
        for (final species in subgroup.species) {
          if (species.toLowerCase().contains(keyword)) {
            _selectedCategory = category.name;
            _selectedSubgroup = subgroup.name;
            _selectedSpecies = species;
            return;
          }
        }
      }
    }
  }

  /// Free tier: Dog and Cat only. Hobby tier adds Rabbit and any Chicken
  /// breed. Every other species needs Pro.
  bool _isSpeciesLocked(String species, UserTier tier) {
    if (tier == UserTier.pro) return false;
    if (species == 'Dog' || species == 'Cat') return false;
    if (tier == UserTier.tier1) {
      return !(species == 'Rabbit' || species.startsWith('Chicken'));
    }
    return true;
  }

  SpeciesCategory get _currentCategory => _catalog.firstWhere((c) => c.name == _selectedCategory);

  SpeciesSubgroup get _currentSubgroup =>
      _currentCategory.subgroups.firstWhere((s) => s.name == _selectedSubgroup, orElse: () => _currentCategory.subgroups.first);

  /// Subgroups that are herbivores/grain-and-forage eaters across the board -
  /// "Whole Prey / Feeder Animals" never makes sense here, unlike Reptile,
  /// Amphibian, or the Exotic Mammals/Companion Mammals subgroups that mix in
  /// real predators (ferret, skunk, serval, dog, cat, etc.).
  static const Set<String> _wholePreyIncompatibleSubgroups = {
    'Livestock & Ruminants',
    'Poultry & Waterfowl',
    'Companion Birds',
    'Rodents',
    'Primates & Prosimians',
    'Marsupials',
  };

  /// Individual herbivore species that share an otherwise-predator-friendly
  /// subgroup (e.g. Rabbit sits in Companion Mammals next to Dog/Cat; Alpaca/
  /// Llama/Sheep/Reindeer are lumped into the catalog's "Exotic Mammals").
  static const Set<String> _wholePreyIncompatibleSpecies = {
    'Rabbit',
    'Alpaca',
    'Llama',
    'Sheep',
    'Reindeer',
  };

  bool _isFeedingSystemRelevant(String system) {
    if (system != 'Whole Prey / Feeder Animals') return true;
    if (_wholePreyIncompatibleSubgroups.contains(_selectedSubgroup)) return false;
    if (_wholePreyIncompatibleSpecies.contains(_selectedSpecies)) return false;
    return true;
  }

  /// Mirrors [_dropProductionStageIfIrrelevant]: resets the selected feeding
  /// system back to the default if switching category/subgroup/species made
  /// it biologically irrelevant (e.g. was "Whole Prey", species changed from
  /// Cat to Sheep).
  void _dropFeedingSystemIfIrrelevant() {
    if (!_isFeedingSystemRelevant(_selectedFeedingSystem)) {
      _selectedFeedingSystem = 'Total Mixed Ration (TMR)';
    }
  }

  /// Filters out production stages that don't make biological sense for the
  /// selected category/subgroup (e.g. "Active Layer" for a Dog) - stages not
  /// called out here (Healthy/Normal, Breeder/Production, Breeder/High
  /// Output, Growth Boost/Juvenile) are broadly applicable so stay
  /// unrestricted rather than guessing per species.
  bool _isProductionStageRelevant(String stage) {
    final isPoultry = _selectedCategory == 'Livestock / Companion' && _selectedSubgroup == 'Poultry & Waterfowl';
    final isRuminantOrEquine = _selectedCategory == 'Livestock / Companion' && _selectedSubgroup == 'Livestock & Ruminants';
    final isCompanionMammal = _selectedCategory == 'Livestock / Companion' && _selectedSubgroup == 'Companion Mammals';
    final isBird = _selectedCategory == 'Bird';
    final isReptileOrAmphibian = _selectedCategory == 'Reptile' || _selectedCategory == 'Amphibian';
    final isMammalLike =
        _selectedCategory == 'Mammal' || _selectedCategory == 'Marsupial' || _selectedCategory == 'Rodent' || isRuminantOrEquine || isCompanionMammal;

    switch (stage) {
      case 'Active Layer':
        return isPoultry;
      case 'Lactating / Nursing':
        return isMammalLike;
      case 'Molting / Recovery':
        return isBird || isReptileOrAmphibian || isPoultry;
      case 'Working / Performance':
        return isRuminantOrEquine || isCompanionMammal;
      default:
        return true;
    }
  }

  /// Resets the selected production stage back to the default if switching
  /// category/subgroup made it irrelevant (e.g. was "Active Layer", category
  /// changed from Poultry to Dog) - mirrors the existing reset-on-change
  /// pattern already used for subgroup/species below.
  void _dropProductionStageIfIrrelevant() {
    if (!_isProductionStageRelevant(_selectedProductionStage)) {
      _selectedProductionStage = 'Healthy / Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<DatabaseService>().speciesCatalog;
    _initFromCatalog(catalog);

    final tier = context.watch<TierService>().tier;
    final canHaveMultiple = tier.isPaid;
    final isPro = tier == UserTier.pro;

    final isEditing = widget.profileToEdit != null;

    if (!_initialized) {
      return const Dialog(
        backgroundColor: Color(0xFF242426),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
        ),
      );
    }

    final availableSubgroups = _currentCategory.subgroups;
    final showSubgroupPicker = availableSubgroups.length > 1;
    final availableSpecies = _currentSubgroup.species;
    if (!availableSpecies.contains(_selectedSpecies) && availableSpecies.isNotEmpty) {
      _selectedSpecies = availableSpecies.first;
    }

    final visibleProductionStages = _productionStages
        .where(_isProductionStageRelevant)
        .where((s) => tier.isPaid || !_lockedProductionStages.contains(s))
        .toList();
    if (!visibleProductionStages.contains(_selectedProductionStage)) {
      visibleProductionStages.add(_selectedProductionStage);
    }

    final visibleFeedingSystems = _feedingSystems.where(_isFeedingSystemRelevant).toList();
    if (!visibleFeedingSystems.contains(_selectedFeedingSystem)) {
      visibleFeedingSystems.add(_selectedFeedingSystem);
    }

    return Dialog(
      backgroundColor: const Color(0xFF242426),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF97316), width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Profile' : 'Add Animal or Flock Profile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Profile Name',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Enter a profile name' : null,
                ),
                const SizedBox(height: 12),

                _buildDropdown(
                  label: 'Category',
                  value: _selectedCategory,
                  items: _catalog.map((c) => c.name).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                      _selectedSubgroup = _currentCategory.subgroups.first.name;
                      _selectedSpecies = _currentCategory.subgroups.first.species.first;
                      _dropProductionStageIfIrrelevant();
                      _dropFeedingSystemIfIrrelevant();
                    });
                  },
                ),
                if (showSubgroupPicker) ...[
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: 'Type',
                    value: _selectedSubgroup,
                    items: availableSubgroups.map((s) => s.name).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSubgroup = val;
                        _selectedSpecies = _currentSubgroup.species.first;
                        _dropProductionStageIfIrrelevant();
                        _dropFeedingSystemIfIrrelevant();
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Species',
                  value: _selectedSpecies,
                  items: availableSpecies,
                  lockedItems: availableSpecies.where((s) => _isSpeciesLocked(s, tier)).toList(),
                  onChanged: (val) {
                    if (_isSpeciesLocked(val, tier)) {
                      showDialog(context: context, builder: (context) => const UpgradeDialog());
                      return;
                    }
                    setState(() {
                      _selectedSpecies = val;
                      _dropFeedingSystemIfIrrelevant();
                    });
                  },
                ),
                if (!isPro) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tier == UserTier.tier1
                              ? 'Dog, Cat, Rabbit & Chicken are included. Every other species needs Pro.'
                              : 'Dog and Cat are included. Every other species needs Pro.',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          showDialog(context: context, builder: (context) => const UpgradeDialog());
                        },
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                Builder(builder: (context) {
                  if (!canHaveMultiple && _headCountController.text != '1') {
                    _headCountController.text = '1';
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _headCountController,
                              enabled: canHaveMultiple,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Head Count',
                                labelStyle: const TextStyle(color: Colors.white60),
                                filled: true,
                                fillColor: const Color(0xFF1A1A1C),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (val) => val == null || int.tryParse(val) == null ? 'Valid number' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              label: 'Environment',
                              value: _selectedEnvironment,
                              items: _environments,
                              onChanged: (val) => setState(() => _selectedEnvironment = val),
                            ),
                          ),
                        ],
                      ),
                      if (!canHaveMultiple) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Upgrade to Hobby Tier to add multiple animals, flock & herd options.',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => const UpgradeDialog(),
                                );
                              },
                              child: const Text(
                                'Upgrade',
                                style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                }),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: 'Sex',
                        value: _selectedSex,
                        items: _sexes,
                        onChanged: (val) => setState(() => _selectedSex = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Age Group',
                        value: _selectedAgeGroup,
                        items: _ageGroups,
                        onChanged: (val) => setState(() => _selectedAgeGroup = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildDropdown(
                  label: 'Animal Health / Production State',
                  value: _selectedProductionStage,
                  items: visibleProductionStages,
                  onChanged: (val) => setState(() => _selectedProductionStage = val),
                ),
                if (!tier.isPaid) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Molting/Recovery, Lactating/Nursing, Breeder/High Output & Growth Boost need Hobby Tier.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          showDialog(context: context, builder: (context) => const UpgradeDialog());
                        },
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                _buildDropdown(
                  label: 'Feeding System',
                  value: _selectedFeedingSystem,
                  items: visibleFeedingSystems,
                  onChanged: (val) => setState(() => _selectedFeedingSystem = val),
                ),
                if (!visibleFeedingSystems.contains('Whole Prey / Feeder Animals')) ...[
                  const SizedBox(height: 8),
                  const Text(
                    "Whole Prey / Feeder Animals isn't offered for this species - it doesn't fit as a diet.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (_isSpeciesLocked(_selectedSpecies, tier)) {
                        showDialog(context: context, builder: (context) => const UpgradeDialog());
                        return;
                      }
                      if (_formKey.currentState!.validate()) {
                        final savedProfile = AnimalProfile(
                          id: widget.profileToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          name: _nameController.text.trim(),
                          species: '$_selectedCategory: $_selectedSpecies',
                          headCount: int.parse(_headCountController.text.trim()),
                          productionStage: _selectedProductionStage,
                          environment: _selectedEnvironment,
                          sex: _selectedSex,
                          ageGroup: _selectedAgeGroup,
                          feedingSystem: _selectedFeedingSystem,
                        );
                        widget.onProfileSaved(savedProfile);
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      isEditing ? 'Update Profile' : 'Save Profile',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1C),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    List<String> lockedItems = const [],
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: const Color(0xFF242426),
      style: const TextStyle(color: Colors.white),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: const Color(0xFF1A1A1C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: items
          .map((i) => DropdownMenuItem(
                value: i,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _feedingSystemLabels[i] ?? i,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (lockedItems.contains(i)) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock, size: 14, color: Colors.white38),
                    ],
                  ],
                ),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}
