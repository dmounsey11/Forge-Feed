import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/animal_profile.dart';
import '../models/health_screening_result.dart';
import '../models/ingredient.dart';
import '../models/ration_result.dart';
import '../services/database_service.dart';
import '../services/diet_calculator.dart';
import '../services/nutrition_target_resolver.dart';
import '../services/tier_service.dart';
import '../widgets/add_profile_dialog.dart';
import '../widgets/health_options_section.dart';
import '../widgets/prep_amount_dialog.dart';
import '../widgets/upgrade_dialog.dart';
import 'ration_result_screen.dart';

enum _CreateFeedStage { closed, profilePicker, baseIngredients }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _CreateFeedStage _stage = _CreateFeedStage.closed;
  AnimalProfile? _selectedProfile;
  PrepAmountResult? _prepResult;
  Set<String> _selectedPantryIds = {};
  HealthScreeningResult? _healthResult;
  RationCalculationError? _lastError;

  void _resetToStart() {
    setState(() {
      _selectedProfile = null;
      _prepResult = null;
      _selectedPantryIds = {};
      _healthResult = null;
      _lastError = null;
      _stage = _CreateFeedStage.profilePicker;
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
      _selectedPantryIds = {};
      _healthResult = null;
      _stage = _CreateFeedStage.baseIngredients;
    });
  }

  void _openAddProfileDialog() {
    final db = context.read<DatabaseService>();
    final tier = context.read<TierService>().tier;
    final limit = tier.maxAnimalProfiles;
    if (limit != null && db.profiles.length >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tier.label} allows up to $limit animal profiles.'),
          action: SnackBarAction(
            label: 'Upgrade',
            onPressed: () => showDialog(context: context, builder: (context) => const UpgradeDialog()),
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AddProfileDialog(
        onProfileSaved: (newProfile) => db.addProfile(newProfile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final tier = context.watch<TierService>().tier;

    Widget body;
    switch (_stage) {
      case _CreateFeedStage.closed:
        body = _buildCreateFeedButton();
      case _CreateFeedStage.profilePicker:
        body = _buildProfilePicker(db.profiles);
      case _CreateFeedStage.baseIngredients:
        body = _buildBaseIngredientsStage(_pantryItemsForSelectedProfile(db.getPantryIngredients()), tier);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: body,
        ),
      ),
    );
  }

  Widget _buildCreateFeedButton() {
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _stage = _CreateFeedStage.profilePicker),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Image.asset('assets/images/createbutton.png'),
        ),
      ),
    );
  }

  Widget _buildProfilePicker(List<AnimalProfile> profiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _stage = _CreateFeedStage.closed),
          icon: const Icon(Icons.arrow_back, color: Colors.white60, size: 18),
          label: const Text('Back', style: TextStyle(color: Colors.white60)),
        ),
        const SizedBox(height: 4),
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

  String get _prepLabel {
    final prep = _prepResult!;
    return prep.mode == PrepMode.days
        ? '${prep.value.toStringAsFixed(0)} day${prep.value == 1 ? '' : 's'}'
        : '${prep.value.toStringAsFixed(1)} lbs';
  }

  /// "Whole Prey" pantry items (mice, rats, quail, rabbit, etc.) are only
  /// meaningful for a profile whose feeding system is actually "Whole Prey /
  /// Feeder Animals" - otherwise they'd show up as selectable base
  /// ingredients for any animal, including ones that shouldn't be eating
  /// whole prey at all.
  List<Ingredient> _pantryItemsForSelectedProfile(List<Ingredient> allPantryItems) {
    if (_selectedProfile?.feedingSystem == 'Whole Prey / Feeder Animals') {
      return allPantryItems;
    }
    return allPantryItems.where((item) => item.category != 'Whole Prey').toList();
  }

  Widget _buildBaseIngredientsStage(List<Ingredient> pantryItems, UserTier tier) {
    final profile = _selectedProfile!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _resetToStart,
          icon: const Icon(Icons.arrow_back, color: Colors.white60, size: 18),
          label: const Text('Change Animal', style: TextStyle(color: Colors.white60)),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Base Ingredients',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (pantryItems.isNotEmpty)
              TextButton(
                onPressed: () => _toggleSelectAll(pantryItems),
                child: Text(
                  _selectedPantryIds.length == pantryItems.length ? 'Deselect All' : 'Select All',
                  style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        Text(
          'For ${profile.name} - prepping $_prepLabel. Pick which pantry items go in this batch. '
          "Any supplements you've stocked are applied automatically to close nutrient gaps the base feed can't cover.",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: pantryItems.isEmpty
              ? _buildEmptyCard('No pantry items in stock yet. Head to the Pantry tab to add some.')
              : ListView(
                  children: [
                    _buildIngredientChecklist(
                      items: pantryItems,
                      selectedIds: _selectedPantryIds,
                      onToggle: (id, selected) => setState(() {
                        if (selected) {
                          _selectedPantryIds.add(id);
                        } else {
                          _selectedPantryIds.remove(id);
                        }
                      }),
                      shrinkWrap: true,
                    ),
                    const SizedBox(height: 20),
                    HealthOptionsSection(
                      key: ValueKey(profile.id),
                      profile: profile,
                      tier: tier,
                      initialResult: _healthResult,
                      onResultChanged: (result) => setState(() => _healthResult = result),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        if (_lastError != null) ...[
          _buildDiagnosticBanner(_lastError!),
          const SizedBox(height: 12),
        ],
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

  void _toggleSelectAll(List<Ingredient> pantryItems) {
    setState(() {
      if (_selectedPantryIds.length == pantryItems.length) {
        _selectedPantryIds = {};
      } else {
        _selectedPantryIds = pantryItems.map((item) => item.id).toSet();
      }
    });
  }

  Widget _buildIngredientChecklist({
    required List<Ingredient> items,
    required Set<String> selectedIds,
    required void Function(String id, bool selected) onToggle,
    bool shrinkWrap = false,
  }) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          color: const Color(0xFF242426),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF3A3A3D)),
          ),
          child: CheckboxListTile(
            value: selectedIds.contains(item.id),
            activeColor: const Color(0xFFF97316),
            checkColor: const Color(0xFF1A1A1C),
            title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${item.category} | CP: ${item.asFedMetrics.crudeProteinPct}% | Ca: ${item.asFedMetrics.calciumPct}%',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            onChanged: (checked) => onToggle(item.id, checked ?? false),
          ),
        );
      },
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
        child: Text(message, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
      ),
    );
  }

  /// Gathers the profile/pantry/supplement inputs and calls
  /// [DietCalculator.calculate]. Returns `null` for the two input problems
  /// (no species data, no pantry selected) that are shown as one-shot
  /// SnackBars rather than the interactive diagnostic banner - those aren't
  /// something a "suggest ingredients"/"relax targets" retry can help with.
  /// Shared by [_calculateDiet] and [_retryWithRelaxation] so a relaxed
  /// retry doesn't duplicate this setup.
  Object? _computeResult({List<NutrientRelaxation>? relaxations}) {
    final profile = _selectedProfile!;
    final prep = _prepResult!;
    final db = context.read<DatabaseService>();

    final target = NutritionTargetResolver.resolve(profile, db.speciesRequirements);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No nutrition data available yet for this species.')),
      );
      return null;
    }

    final selectedPantryItems = db.getPantryIngredients().where((i) => _selectedPantryIds.contains(i.id)).toList();
    // Supplements aren't manually checked - every stocked supplement is
    // handed to the calculator, which only actually uses the ones needed to
    // close the calcium/phosphorus/sodium gap the base feed can't cover.
    final availableSupplementItems = db.getSupplementIngredients();

    if (selectedPantryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one pantry item before calculating a diet.')),
      );
      setState(() => _stage = _CreateFeedStage.baseIngredients);
      return null;
    }

    return DietCalculator.calculate(
      profile: profile,
      target: target,
      health: _healthResult,
      prep: prep,
      pantryItems: selectedPantryItems,
      supplementItems: availableSupplementItems,
      safetyRules: db.safetyRules,
      stageHasDedicatedData: NutritionTargetResolver.stageHasDedicatedData(profile, db.speciesRequirements),
      relaxations: relaxations,
    );
  }

  void _calculateDiet() {
    final result = _computeResult();
    if (result == null) return;

    if (result is RationCalculationError) {
      setState(() => _lastError = result);
      return;
    }

    setState(() => _lastError = null);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RationResultScreen(result: result as RationResult, profileName: _selectedProfile!.name),
      ),
    );
  }

  /// "Allow temporary target relaxation": loosens exactly the nutrient
  /// bound(s) the diagnostic pass already identified in [_lastError] to
  /// their computed achievable value, then re-solves. The relaxed
  /// [RationResult] carries its own "target relaxed" warning (added by
  /// [DietCalculator.calculate]) so the result screen makes clear this
  /// batch isn't at the animal's normal target.
  void _retryWithRelaxation() {
    final bottlenecks = _lastError!.bottlenecks;
    final relaxations = bottlenecks
        .map((b) => NutrientRelaxation(
              label: b.label,
              unit: b.unit,
              isMinBound: b.isMinBound,
              relaxedValue: b.achievableValue,
            ))
        .toList();

    final result = _computeResult(relaxations: relaxations);
    if (result == null) return;

    if (result is RationResult) {
      setState(() => _lastError = null);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RationResultScreen(result: result, profileName: _selectedProfile!.name),
        ),
      );
    } else if (result is RationCalculationError) {
      // Defensive - relaxing exactly the identified bottleneck should
      // normally succeed, but surface a fresh diagnostic if it doesn't.
      setState(() => _lastError = result);
    }
  }

  void _showSuggestionsDialog(RationCalculationError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF242426),
        title: const Text('Suggested ingredients', style: TextStyle(color: Colors.white)),
        content: Text(
          DietCalculator.suggestMissingIngredients(error.bottlenecks),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFFF97316))),
          ),
        ],
      ),
    );
  }

  /// Interactive replacement for the old one-shot SnackBar: a persistent,
  /// dismissible card so a failed solve can offer follow-up actions instead
  /// of just naming the failure once and vanishing. Only shows the two
  /// action chips when [error.bottlenecks] is non-empty - a generic/
  /// unexplained infeasibility (e.g. rooted in a hard safety constraint)
  /// has nothing concrete for "suggest ingredients"/"relax targets" to act
  /// on.
  Widget _buildDiagnosticBanner(RationCalculationError error) {
    final hasBottlenecks = error.bottlenecks.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasBottlenecks ? DietCalculator.describeBottlenecks(error.bottlenecks) : error.message,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _lastError = null),
                child: const Icon(Icons.close, color: Colors.white54, size: 18),
              ),
            ],
          ),
          if (hasBottlenecks) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  backgroundColor: const Color(0xFF242426),
                  label: const Text('Suggest missing ingredients', style: TextStyle(color: Colors.white)),
                  onPressed: () => _showSuggestionsDialog(error),
                ),
                ActionChip(
                  backgroundColor: const Color(0xFFF97316),
                  label: const Text(
                    'Allow temporary target relaxation',
                    style: TextStyle(color: Color(0xFF1A1A1C), fontWeight: FontWeight.bold),
                  ),
                  onPressed: _retryWithRelaxation,
                ),
              ],
            ),
          ],
        ],
      ),
    );
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
