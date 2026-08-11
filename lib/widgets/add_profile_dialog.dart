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
  bool _initialized = false;

  final List<String> _sexes = ['Unknown', 'Male', 'Female', 'Mixed'];
  final List<String> _ageGroups = ['Baby', 'Juvenile', 'Adult', 'Geriatric'];
  final List<String> _environments = ['Outdoor', 'Indoor', 'Hybrid / Pasture'];
  final List<String> _productionStages = [
    'Healthy / Normal',
    'Active Layer',
    'Breeder / Production',
    'Molting / Recovery 🔒',
    'Lactating / Nursing 🔒',
    'Breeder / High Output 🔒',
    'Growth Boost / Juvenile 🔒',
  ];

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
  }

  void _initFromCatalog(List<SpeciesCategory> catalog) {
    if (_initialized || catalog.isEmpty) return;
    _initialized = true;
    _catalog = catalog;

    _selectedCategory = catalog.first.name;
    _selectedSubgroup = catalog.first.subgroups.first.name;
    _selectedSpecies = catalog.first.subgroups.first.species.first;

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

  SpeciesCategory get _currentCategory => _catalog.firstWhere((c) => c.name == _selectedCategory);

  SpeciesSubgroup get _currentSubgroup =>
      _currentCategory.subgroups.firstWhere((s) => s.name == _selectedSubgroup, orElse: () => _currentCategory.subgroups.first);

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<DatabaseService>().speciesCatalog;
    _initFromCatalog(catalog);

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
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Species',
                  value: _selectedSpecies,
                  items: availableSpecies,
                  onChanged: (val) => setState(() => _selectedSpecies = val),
                ),
                const SizedBox(height: 12),

                Builder(builder: (context) {
                  final tier = context.watch<TierService>().tier;
                  final canHaveMultiple = tier.isPaid;
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
                  items: _productionStages,
                  onChanged: (val) => setState(() => _selectedProductionStage = val),
                ),
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
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}
