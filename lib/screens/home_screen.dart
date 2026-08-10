import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pantry_item.dart';
import '../models/ingredient.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    super.dispose();
  }

  void _showAddPantryDialog() {
    nameController.clear();
    qtyController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161F1A),
          title: const Text(
            'Add Pantry Item',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Quantity (lbs)',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84CC16),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final qty = double.tryParse(qtyController.text) ?? 0.0;

                if (name.isNotEmpty && qty > 0) {
                  final newId = DateTime.now().millisecondsSinceEpoch.toString();

                  final dbService =
                      Provider.of<DatabaseService>(context, listen: false);

                  // Create ingredient model wrapper
                  final customIngredient = Ingredient(
                    id: newId,
                    name: name,
                    category: 'Custom',
                  );

                  dbService.addPantryItem(
                    PantryItem(
                      id: newId,
                      ingredient: customIngredient,
                      quantityLbs: qty,
                    ),
                  );

                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(
                  color: Color(0xFF0D1117),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161F1A),
        title: const Text('ForgeFeed Home'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF84CC16),
          ),
          onPressed: _showAddPantryDialog,
          icon: const Icon(Icons.add, color: Color(0xFF0D1117)),
          label: const Text(
            'Add Pantry Item',
            style: TextStyle(
              color: Color(0xFF0D1117),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}