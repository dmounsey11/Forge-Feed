import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/ingredient.dart';

class MasterIngredientPicker extends StatefulWidget {
  final ValueChanged<Ingredient>? onIngredientSelected;
  final bool isSupplementMode;

  const MasterIngredientPicker({
    super.key,
    this.onIngredientSelected,
    this.isSupplementMode = false,
  });

  @override
  State<MasterIngredientPicker> createState() => _MasterIngredientPickerState();
}

class _MasterIngredientPickerState extends State<MasterIngredientPicker> {
  static const List<String> _foodCategories = [
    'Grains & Cereals',
    'Proteins & Meal',
    'Forages & Roughage',
    'Produce',
    'Fruits',
    'Whole Prey',
    'Store Feed',
  ];

  static const List<String> _nutrientCategories = [
    'Natural Supplements',
    'Vitamins & Minerals',
    'Probiotics & Digestive',
  ];

  String _searchQuery = '';
  late String _selectedGroup = _allGroupLabel;

  String get _allGroupLabel => widget.isSupplementMode ? 'All Nutrient Groups' : 'All Categories';

  List<String> get _groups => [
        _allGroupLabel,
        ...(widget.isSupplementMode ? _nutrientCategories : _foodCategories),
      ];

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final modeCategories = widget.isSupplementMode ? _nutrientCategories : _foodCategories;
    final allIngredients = db.masterIngredients.where((item) => modeCategories.contains(item.category));

    final filteredIngredients = allIngredients.where((item) {
      final query = _searchQuery.toLowerCase();
      final queryMatches = item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.subCategory.toLowerCase().contains(query) ||
          item.brand.toLowerCase().contains(query);
      final groupMatches = _selectedGroup == _allGroupLabel || item.category == _selectedGroup;
      return queryMatches && groupMatches;
    }).toList();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF97316), width: 1.5),
      ),
      child: Container(
        width: 800,
        height: 650,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isSupplementMode ? Icons.science : Icons.storage,
                    color: const Color(0xFFF97316),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isSupplementMode
                          ? 'Supplement & Additive Library'
                          : 'Ingredient Catalog',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      widget.isSupplementMode
                          ? 'Select vitamins, minerals, and probiotics for on-hand stock'
                          : 'Browse USDA Standard Reference items and commercial store feed products',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search and Category Dropdown Group Filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search database (e.g. Corn, Barley, Calcium)...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF97316)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGroup,
                      dropdownColor: const Color(0xFF2C2C2E),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      items: _groups.map((g) {
                        return DropdownMenuItem(value: g, child: Text(g));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGroup = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Item Cards List
            Expanded(
              child: filteredIngredients.isEmpty
                  ? const Center(child: Text('No matching items found.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filteredIngredients.length,
                      itemBuilder: (context, index) {
                        final ing = filteredIngredients[index];
                        final inStock = widget.isSupplementMode
                            ? db.isInSupplements(ing.id)
                            : db.isInPantry(ing.id);

                        return Card(
                          color: const Color(0xFF2C2C2E),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ing.name,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          if (ing.category == 'Store Feed')
                                            Text(
                                              '${ing.brand} · ${ing.subCategory}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        ing.category,
                                        style: const TextStyle(color: Color(0xFFF97316), fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _buildNutrientBadge('CP', '${ing.asFedMetrics.crudeProteinPct}%'),
                                    _buildNutrientBadge('Fat', '${ing.asFedMetrics.crudeFatPct}%'),
                                    _buildNutrientBadge('Fiber', '${ing.asFedMetrics.crudeFiberPct}%'),
                                    _buildNutrientBadge('Ca', '${ing.asFedMetrics.calciumPct}%'),
                                    _buildNutrientBadge('P', '${ing.asFedMetrics.phosphorusPct}%'),
                                    _buildNutrientBadge('ME', '${ing.asFedMetrics.energyKcalLb} kcal/lb'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: inStock ? Colors.red.shade900 : const Color(0xFFF97316),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: Icon(inStock ? Icons.remove_circle : Icons.add_circle),
                                    label: Text(
                                      inStock
                                          ? 'Remove from On-Hand'
                                          : (widget.isSupplementMode ? '+ Import to Supplements' : '+ Import to Pantry'),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (widget.isSupplementMode) {
                                          db.toggleSupplementItem(ing.id);
                                        } else {
                                          db.togglePantryItem(ing.id);
                                        }
                                      });
                                      if (widget.onIngredientSelected != null) {
                                        widget.onIngredientSelected!(ing);
                                      }
                                    },
                                  ),
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
      ),
    );
  }

  Widget _buildNutrientBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}