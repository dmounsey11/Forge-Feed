import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/pantry_controller.dart';
import '../models/ingredient.dart';


class AddCustomIngredientDialog extends StatefulWidget {
  const AddCustomIngredientDialog({super.key, required Null Function(Ingredient) onIngredientSelected});

  @override
  State<AddCustomIngredientDialog> createState() => _AddCustomIngredientDialogState();
}

class _AddCustomIngredientDialogState extends State<AddCustomIngredientDialog> {
  final _nameController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _calciumController = TextEditingController();
  final _phosphorusController = TextEditingController();
  final _energyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _calciumController.dispose();
    _phosphorusController.dispose();
    _energyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Ingredient'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Ingredient Name')),
            TextField(controller: _proteinController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Crude Protein (%)')),
            TextField(controller: _fatController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Crude Fat (%)')),
            TextField(controller: _fiberController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Crude Fiber (%)')),
            TextField(controller: _calciumController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calcium (%)')),
            TextField(controller: _phosphorusController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Phosphorus (%)')),
            TextField(controller: _energyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Energy (kcal/lb)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              final newIngredient = Ingredient(
                id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                name: _nameController.text.trim(),
                category: 'Custom',
                proteinPct: double.tryParse(_proteinController.text) ?? 0.0,
                fatPctValue: double.tryParse(_fatController.text) ?? 0.0,
                fiberPctValue: double.tryParse(_fiberController.text) ?? 0.0,
                calciumPctValue: double.tryParse(_calciumController.text) ?? 0.0,
                phosphorusPctValue: double.tryParse(_phosphorusController.text) ?? 0.0,
                energyMeKcalLb: double.tryParse(_energyController.text) ?? 0.0,
              );

              Provider.of<PantryController>(context, listen: false).addPantryItem(newIngredient, 0.0);
              Navigator.pop(context);
            }
          },
          child: const Text('Save Ingredient'),
        ),
      ],
    );
  }
}