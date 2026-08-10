// lib/screens/ration_calculator_screen.dart
import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../models/animal_profile.dart';
import '../widgets/master_ingredient_picker.dart';

class RationCalculatorScreen extends StatefulWidget {
  const RationCalculatorScreen({super.key});

  @override
  State<RationCalculatorScreen> createState() => _RationCalculatorScreenState();
}

class _RationCalculatorScreenState extends State<RationCalculatorScreen> {
  // Selected Animal/Flock Profile for Target Targets
  AnimalProfile? _selectedProfile;

  // Active Ingredients in Current Batch Formulator
  final List<Ingredient> _selectedIngredients = [];

  // Track Inclusion Percentages (ID -> Percentage, e.g., 'corn': 60.0)
  final Map<String, double> _inclusionRatios = {};

  // Mock list of profiles - Replace with your DatabaseService/Storage load later
  final List<AnimalProfile> _availableProfiles = [
    AnimalProfile(
      id: 'profile_quail_grower',
      name: 'Coturnix Quail - Meat Grower',
      species: 'Quail',
      stage: 'Grower',
      targetProteinPct: 24.0,
      targetFatPct: 4.0,
      targetFiberPct: 6.0,
      targetCalciumPct: 1.0,
      targetPhosphorusPct: 0.45,
    ),
    AnimalProfile(
      id: 'profile_poultry_layer',
      name: 'Layer Flock - Active Egg Production',
      species: 'Poultry',
      stage: 'Layer',
      targetProteinPct: 16.0,
      targetFatPct: 3.5,
      targetFiberPct: 5.0,
      targetCalciumPct: 3.8,
      targetPhosphorusPct: 0.45,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (_availableProfiles.isNotEmpty) {
      _selectedProfile = _availableProfiles.first;
    }
  }

  // Opens the Master Ingredient Picker Modal (Including + Custom Tag button)
  void _openIngredientPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MasterIngredientPicker(
        onIngredientSelected: (Ingredient selectedIngredient) {
          setState(() {
            // Avoid duplicates
            if (!_selectedIngredients.any((item) => item.id == selectedIngredient.id)) {
              _selectedIngredients.add(selectedIngredient);
              
              // Set default ratio split evenly across selected ingredients
              final defaultShare = 100.0 / _selectedIngredients.length;
              for (var item in _selectedIngredients) {
                _inclusionRatios[item.id] = defaultShare;
              }
            }
          });
        },
      ),
    );
  }

  // Calculates the batch total Crude Protein % based on inclusion weights
  double _calculateTotalProtein() {
    if (_selectedIngredients.isEmpty) return 0.0;
    double totalWeight = _inclusionRatios.values.fold(0.0, (sum, val) => sum + val);
    if (totalWeight == 0) return 0.0;

    double weightedProtein = 0.0;
    for (var item in _selectedIngredients) {
      final ratio = (_inclusionRatios[item.id] ?? 0.0) / totalWeight;
      weightedProtein += (item.asFedMetrics.crudeProteinPct * ratio);
    }
    return weightedProtein;
  }

  @override
  Widget build(BuildContext context) {
    final calculatedProtein = _calculateTotalProtein();
    final targetProtein = _selectedProfile?.targetProteinPct ?? 0.0;
    final totalPercentage = _inclusionRatios.values.fold(0.0, (sum, val) => sum + val);

    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      appBar: AppBar(
        title: const Text('Ration Calculator & Formulator'),
        backgroundColor: const Color(0xFF1F293D),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Profile Selector Header
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF1F293D),
            child: Row(
              children: [
                const Icon(Icons.pets, color: Color(0xFF10B981)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AnimalProfile>(
                      value: _selectedProfile,
                      dropdownColor: const Color(0xFF1F293D),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      isExpanded: true,
                      items: _availableProfiles.map((profile) {
                        return DropdownMenuItem(
                          value: profile,
                          child: Text(profile.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedProfile = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Calculated Batch Metrics vs Target Summary Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1F293D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (totalPercentage - 100.0).abs() < 0.1
                    ? const Color(0xFF10B981)
                    : Colors.orangeAccent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn(
                  'Calculated CP',
                  '${calculatedProtein.toStringAsFixed(1)}%',
                  calculatedProtein >= targetProtein ? const Color(0xFF10B981) : Colors.amberAccent,
                ),
                _buildMetricColumn(
                  'Target CP',
                  '${targetProtein.toStringAsFixed(1)}%',
                  Colors.grey,
                ),
                _buildMetricColumn(
                  'Batch Total',
                  '${totalPercentage.toStringAsFixed(0)}%',
                  (totalPercentage - 100.0).abs() < 0.1 ? const Color(0xFF10B981) : Colors.redAccent,
                ),
              ],
            ),
          ),

          // 3. Ingredient Formulator List
          Expanded(
            child: _selectedIngredients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.rice_bowl_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No ingredients added to current batch.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _openIngredientPicker,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Ingredients / Tags'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: _selectedIngredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = _selectedIngredients[index];
                      final currentRatio = _inclusionRatios[ingredient.id] ?? 0.0;

                      return Card(
                        color: const Color(0xFF1F293D),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ingredient.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _selectedIngredients.removeAt(index);
                                        _inclusionRatios.remove(ingredient.id);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                'CP: ${ingredient.asFedMetrics.crudeProteinPct}% | Fat: ${ingredient.asFedMetrics.crudeFatPct}%',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: currentRatio.clamp(0.0, 100.0),
                                      min: 0.0,
                                      max: 100.0,
                                      divisions: 100,
                                      activeColor: const Color(0xFF10B981),
                                      inactiveColor: Colors.black26,
                                      onChanged: (newVal) {
                                        setState(() {
                                          _inclusionRatios[ingredient.id] = newVal;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      '${currentRatio.toStringAsFixed(0)}%',
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedIngredients.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openIngredientPicker,
              backgroundColor: const Color(0xFF10B981),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Feed / Tag', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}