import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../widgets/master_ingredient_picker.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  void _openCatalogModal({bool isSupplementMode = false}) {
    showDialog(
      context: context,
      builder: (context) => MasterIngredientPicker(
        isSupplementMode: isSupplementMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final pantryItems = db.getPantryIngredients();
    final supplementItems = db.getSupplementIngredients();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION 1: MY PANTRY
            _buildSectionHeader(
              title: 'My Pantry',
              subtitle: 'On-hand bulk grains, meals, and primary ration ingredients',
              icon: Icons.inventory_2,
              buttonLabel: '+ Add Pantry Items',
              onPressed: () => _openCatalogModal(isSupplementMode: false),
            ),
            const SizedBox(height: 12),
            pantryItems.isEmpty
                ? _buildEmptyCard('No base pantry items registered in stock.')
                : _buildStockGrid(db, pantryItems, isSupplement: false),

            const SizedBox(height: 32),

            // SECTION 2: MY SUPPLEMENTS
            _buildSectionHeader(
              title: 'My Supplements',
              subtitle: 'Calcium, mineral packs, probiotics, and targeted micro-additives',
              icon: Icons.science,
              buttonLabel: '+ Add Supplements',
              onPressed: () => _openCatalogModal(isSupplementMode: true),
            ),
            const SizedBox(height: 12),
            supplementItems.isEmpty
                ? _buildEmptyCard('No supplements registered in stock.')
                : _buildStockGrid(db, supplementItems, isSupplement: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFF97316), size: 26),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: onPressed,
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF242426),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildStockGrid(DatabaseService db, List items, {required bool isSupplement}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          color: const Color(0xFF2C2C2E),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(
              isSupplement ? Icons.medical_services_outlined : Icons.grain,
              color: const Color(0xFFF97316),
            ),
            title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${item.category} | CP: ${item.asFedMetrics.crudeProteinPct}% | Ca: ${item.asFedMetrics.calciumPct}%',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                if (isSupplement) {
                  db.toggleSupplementItem(item.id);
                } else {
                  db.togglePantryItem(item.id);
                }
              },
            ),
          ),
        );
      },
    );
  }
}