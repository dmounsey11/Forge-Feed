import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/pantry_controller.dart';
import '../models/animal_profile.dart';

class AddProfileDialog extends StatefulWidget {
  const AddProfileDialog({super.key});

  @override
  State<AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<AddProfileDialog> {
  final _speciesController = TextEditingController();
  final _stageController = TextEditingController();
  final _proteinController = TextEditingController(text: '16.0');
  final _fatController = TextEditingController(text: '3.0');
  final _fiberController = TextEditingController(text: '5.0');
  final _energyController = TextEditingController(text: '1300');
  final _calciumController = TextEditingController(text: '1.0');
  final _phosphorusController = TextEditingController(text: '0.45');

  @override
  void dispose() {
    _speciesController.dispose();
    _stageController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _energyController.dispose();
    _calciumController.dispose();
    _phosphorusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Animal Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _speciesController, 
              decoration: const InputDecoration(labelText: 'Species (e.g. Turkey, Goose)'),
            ),
            TextField(
              controller: _stageController, 
              decoration: const InputDecoration(labelText: 'Stage (e.g. Grower, Layer)'),
            ),
            TextField(
              controller: _proteinController, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: 'Target Protein (%)'),
            ),
            TextField(
              controller: _fatController, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: 'Target Fat (%)'),
            ),
            TextField(
              controller: _fiberController, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: 'Target Fiber (%)'),
            ),
            TextField(
              controller: _energyController, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: 'Target Energy (kcal/lb)'),
            ),
            TextField(
              controller: _calciumController, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: 'Target Calcium (%)'),
            ),
            TextField(
              controller: _phosphorusController, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: 'Target Phosphorus (%)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final species = _speciesController.text.trim();
            final stage = _stageController.text.trim();

            if (species.isNotEmpty && stage.isNotEmpty) {
              final newProfile = AnimalProfile(
                id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
                name: '$species ($stage)',
                species: species,
                stage: stage,
                targetProteinPct: double.tryParse(_proteinController.text) ?? 0.0,
                targetFatPct: double.tryParse(_fatController.text) ?? 0.0,
                targetFiberPct: double.tryParse(_fiberController.text) ?? 0.0,
                targetCalciumPct: double.tryParse(_calciumController.text) ?? 0.0,
                targetPhosphorusPct: double.tryParse(_phosphorusController.text) ?? 0.0,
              );
              
              Provider.of<PantryController>(context, listen: false).addCustomTarget(newProfile);
              Navigator.pop(context);
            }
          },
          child: const Text('Save Profile'),
        )
      ],
    );
  }
}