import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/animal_profile.dart';
import '../services/database_service.dart';
import '../services/diet_calculator.dart';
import '../services/nutrition_target_resolver.dart';
import '../services/tier_service.dart';
import '../widgets/add_profile_dialog.dart';
import '../widgets/health_screening_dialog.dart';
import '../widgets/prep_amount_dialog.dart';
import '../widgets/upgrade_dialog.dart';
import 'ration_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AnimalProfile? _selectedProfile;
  PrepAmountResult? _prepResult;
  HealthScreeningResult? _healthResult;
  bool _healthSkipped = false;

  void _reset() {
    setState(() {
      _selectedProfile = null;
      _prepResult = null;
      _healthResult = null;
      _healthSkipped = false;
    });
  }

  Future<void> _selectProfile(AnimalProfile profile) async {
    final prepResult = await showDialog<PrepAmountResult>(
      context: context,
      builder: (context) => const PrepAmountDialog(),
    );
    if (prepResult == null || !mounted) return;

    setState(() {
      _selectedProfile = profile;
      _prepResult = prepResult;
      _healthResult = null;
      _healthSkipped = false;
    });

    final tier = context.read<TierService>().tier;
    if (tier.isPaid) {
      final healthResult = await showDialog<HealthScreeningResult>(
        context: context,
        builder: (context) => HealthScreeningDialog(profile: profile),
      );
      if (!mounted) return;
      setState(() => _healthResult = healthResult ?? const HealthScreeningResult());
    } else {
      final wantsUpgrade = await showDialog<bool>(
        context: context,
        builder: (context) => const HealthUpgradePromptDialog(),
      );
      if (!mounted) return;
      if (wantsUpgrade == true) {
        await showDialog(
          context: context,
          builder: (context) => const UpgradeDialog(),
        );
        if (!mounted) return;
      }
      setState(() => _healthSkipped = true);
    }
  }

  void _openAddProfileDialog() {
    final db = context.read<DatabaseService>();
    showDialog(
      context: context,
      builder: (ctx) => AddProfileDialog(
        onProfileSaved: (newProfile) => db.addProfile(newProfile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<DatabaseService>().profiles;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _selectedProfile == null
              ? _buildProfilePicker(profiles)
              : _buildSessionSummary(),
        ),
      ),
    );
  }

  Widget _buildProfilePicker(List<AnimalProfile> profiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Who are you feeding?',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick an animal or flock to start prepping a feed.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: profiles.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: profiles.length + 1,
                  itemBuilder: (context, index) {
                    if (index == profiles.length) {
                      return _AddProfileCard(onTap: _openAddProfileDialog);
                    }
                    final profile = profiles[index];
                    return _ProfileCard(
                      profile: profile,
                      onTap: () => _selectProfile(profile),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No animal profiles yet.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
            onPressed: _openAddProfileDialog,
            icon: const Icon(Icons.add, color: Color(0xFF1A1A1C)),
            label: const Text(
              'Add Your First Animal',
              style: TextStyle(color: Color(0xFF1A1A1C), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _calculateDiet() {
    final profile = _selectedProfile!;
    final prep = _prepResult!;
    final db = context.read<DatabaseService>();

    final target = NutritionTargetResolver.resolve(profile, db.speciesRequirements);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No nutrition data available yet for this species.')),
      );
      return;
    }

    final pantryItems = db.getPantryIngredients();
    if (pantryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one pantry item before calculating a diet.')),
      );
      return;
    }

    final result = DietCalculator.calculate(
      profile: profile,
      target: target,
      health: _healthSkipped ? null : _healthResult,
      prep: prep,
      pantryItems: pantryItems,
      supplementItems: db.getSupplementIngredients(),
      safetyRules: db.safetyRules,
      stageHasDedicatedData: NutritionTargetResolver.stageHasDedicatedData(profile, db.speciesRequirements),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RationResultScreen(result: result, profileName: profile.name),
      ),
    );
  }

  Widget _buildSessionSummary() {
    final profile = _selectedProfile!;
    final prep = _prepResult!;
    final prepLabel = prep.mode == PrepMode.days
        ? '${prep.value.toStringAsFixed(0)} day${prep.value == 1 ? '' : 's'}'
        : '${prep.value.toStringAsFixed(1)} lbs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.arrow_back, color: Colors.white60, size: 18),
          label: const Text('Change Animal', style: TextStyle(color: Colors.white60)),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF242426),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A3A3D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                style: const TextStyle(color: Color(0xFFF97316), fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${profile.species} - ${profile.sex} - ${profile.ageGroup}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _SummaryRow(label: 'Prepping for', value: prepLabel),
              const SizedBox(height: 8),
              _SummaryRow(label: 'Health notes', value: _healthSummaryText()),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _calculateDiet,
            child: const Text(
              'Calculate Diet',
              style: TextStyle(color: Color(0xFF1A1A1C), fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  String _healthSummaryText() {
    if (_healthSkipped) return 'Skipped (upgrade to add health details)';
    final health = _healthResult;
    if (health == null) return 'Not answered yet';
    if (!health.hasAnyFlag) return 'No flags reported - healthy baseline';

    final notes = <String>[];
    if (health.pregnant) notes.add('Pregnant');
    if (health.breeding) notes.add('Breeding');
    if (health.injured) {
      notes.add(health.injuryNotes.isEmpty ? 'Injured' : 'Injured (${health.injuryNotes})');
    }
    if (health.hibernatingOrBrumating) notes.add('Hibernating/Brumating');
    return notes.join(', ');
  }
}

class _ProfileCard extends StatelessWidget {
  final AnimalProfile profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF242426),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A3A3D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, color: Color(0xFFF97316), size: 28),
            const SizedBox(height: 10),
            Text(
              profile.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              profile.species,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF242426),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF97316), style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFFF97316), size: 28),
            SizedBox(height: 10),
            Text(
              'Add New Animal',
              style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }
}
