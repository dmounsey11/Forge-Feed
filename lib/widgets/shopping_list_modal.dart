import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/pantry_controller.dart';

class ShoppingListModal extends StatelessWidget {
  const ShoppingListModal({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<PantryController>(context);
    final lowStockItems = controller.pantryItems.where((item) => item.quantityLbs < 30.0).toList();

    return Container(
      padding: const EdgeInsets.all(20.0),
      height: 450,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shopping_bag, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Feed Replenishment Shopping List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Items in your pantry with less than 30 lbs stock remaining:', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Expanded(
            child: lowStockItems.isEmpty
                ? const Center(child: Text('All feed stocks are well supplied (>30 lbs)!'))
                : ListView.builder(
                    itemCount: lowStockItems.length,
                    itemBuilder: (context, index) {
                      final item = lowStockItems[index];
                      return ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                        title: Text(item.ingredient.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Current Stock: ${item.quantityLbs.toStringAsFixed(1)} lbs'),
                        trailing: Text('Buy ~${(100 - item.quantityLbs).toStringAsFixed(0)} lbs', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
