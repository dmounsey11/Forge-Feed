import 'package:flutter/material.dart';
import '../models/animal_profile.dart';

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

  final Map<String, List<String>> _categorySpeciesMap = {
    'Livestock': [
      'Poultry (Chicken)',
      'Poultry (Quail)',
      'Poultry (Waterfowl/Duck/Goose)',
      'Poultry (Turkey)',
      'Ruminant (Goat)',
      'Ruminant (Sheep)',
      'Ruminant (Cattle)',
      'Swine (Pig)',
    ],
    'Reptiles': [
      'Lizard',
      'Snake',
      'Turtle / Tortoise',
    ],
    'Companion': [
      'Bird (Parrot/Finch)',
      'Dog',
      'Cat',
      'Rabbit',
    ],
    'Exotic': [
      'Rodent (Squirrel, Groundhog, Capybara)',
      'Marsupial (Kangaroo, Wallaby)',
      'Marsupial (Sugar Glider)',
      'Marsupial (Opossum)',
      'Other Exotic',
    ],
  };

  late String _selectedCategory;
  late String _selectedSpecies;
  late String _selectedEnvironment;
  late String _selectedProductionStage;

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
    _headCountController = TextEditingController(text: edit?.headCount.toString() ?? '10');

    _selectedCategory = _categorySpeciesMap.keys.first;
    _selectedSpecies = _categorySpeciesMap[_selectedCategory]!.first;

    // Pre-select species & category if editing
    if (edit != null) {
      if (edit.species.contains(': ')) {
        final parts = edit.species.split(': ');
        if (_categorySpeciesMap.containsKey(parts[0])) {
          _selectedCategory = parts[0];
          _selectedSpecies = parts[1];
        }
      }
    }

    _selectedEnvironment = edit?.environment ?? 'Outdoor';
    _selectedProductionStage = edit?.productionStage ?? 'Healthy / Normal';
    if (!_productionStages.contains(_selectedProductionStage)) {
      _productionStages.add(_selectedProductionStage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSpecies = _categorySpeciesMap[_selectedCategory] ?? [];
    if (!availableSpecies.contains(_selectedSpecies) && availableSpecies.isNotEmpty) {
      _selectedSpecies = availableSpecies.first;
    }

    final isEditing = widget.profileToEdit != null;

    return Dialog(
      backgroundColor: const Color(0xFF161F1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF84CC16), width: 1.5),
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
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Enter a profile name' : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        dropdownColor: const Color(0xFF161F1A),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF0D1117),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _categorySpeciesMap.keys.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              _selectedSpecies = _categorySpeciesMap[val]!.first;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSpecies,
                        dropdownColor: const Color(0xFF161F1A),
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Species',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF0D1117),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: availableSpecies.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSpecies = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _headCountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Head Count',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF0D1117),
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
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedEnvironment,
                        dropdownColor: const Color(0xFF161F1A),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Environment',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF0D1117),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _environments.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedEnvironment = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _selectedProductionStage,
                  dropdownColor: const Color(0xFF161F1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Animal Health / Production State',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _productionStages.map((stage) => DropdownMenuItem(value: stage, child: Text(stage))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedProductionStage = val);
                  },
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84CC16),
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
                        );
                        widget.onProfileSaved(savedProfile);
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      isEditing ? 'Update Profile' : 'Save Profile',
                      style: const TextStyle(
                        color: Color(0xFF0D1117),
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
}