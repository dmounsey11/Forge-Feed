import 'package:flutter/material.dart';
import '../models/animal_profile.dart';
import '../models/health_screening_result.dart';
import '../services/tier_service.dart';
import 'upgrade_dialog.dart';

/// Inline (non-dialog) health/condition screening, shown at the bottom of
/// the "Add Supplements" step so it sits right next to the final Calculate
/// action instead of interrupting the flow as a popup. Tier-gated, except
/// for the overweight/obese toggle which is available on every tier
/// (including Free) since it's one of the most common conditions pet
/// owners deal with: Free tier gets just that toggle plus an upgrade
/// prompt for the rest; Hobby gets obese + pregnant/breeding; Pro gets the
/// full set (adds injured w/ notes + hibernating/brumating). Reports its
/// result via [onResultChanged] any time something changes - null means
/// "nothing to apply" (toggle off, or nothing enabled on free tier).
class HealthOptionsSection extends StatefulWidget {
  final AnimalProfile profile;
  final UserTier tier;
  final HealthScreeningResult? initialResult;
  final ValueChanged<HealthScreeningResult?> onResultChanged;

  const HealthOptionsSection({
    super.key,
    required this.profile,
    required this.tier,
    required this.initialResult,
    required this.onResultChanged,
  });

  @override
  State<HealthOptionsSection> createState() => _HealthOptionsSectionState();
}

class _HealthOptionsSectionState extends State<HealthOptionsSection> {
  late bool _enabled;
  late bool _pregnant;
  late bool _breeding;
  late bool _injured;
  late bool _hibernatingOrBrumating;
  late bool _obese;
  late final TextEditingController _injuryController;

  bool get _showsPregnant => widget.profile.sex == 'Female' || widget.profile.sex == 'Mixed';
  bool get _showsHibernation =>
      widget.profile.species.startsWith('Reptiles') || widget.profile.species.startsWith('Exotic');
  bool get _isPro => widget.tier == UserTier.pro;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialResult;
    _enabled = initial != null;
    _pregnant = initial?.pregnant ?? false;
    _breeding = initial?.breeding ?? false;
    _injured = initial?.injured ?? false;
    _hibernatingOrBrumating = initial?.hibernatingOrBrumating ?? false;
    _obese = initial?.obese ?? false;
    _injuryController = TextEditingController(text: initial?.injuryNotes ?? '');
  }

  @override
  void dispose() {
    _injuryController.dispose();
    super.dispose();
  }

  void _emit() {
    if (widget.tier == UserTier.free) {
      widget.onResultChanged(_obese ? const HealthScreeningResult(obese: true) : null);
      return;
    }
    if (!_enabled) {
      widget.onResultChanged(null);
      return;
    }
    widget.onResultChanged(HealthScreeningResult(
      pregnant: _pregnant,
      breeding: _breeding,
      injured: _isPro && _injured,
      injuryNotes: _isPro ? _injuryController.text.trim() : '',
      hibernatingOrBrumating: _isPro && _hibernatingOrBrumating,
      obese: _obese,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tier == UserTier.free) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _NonTriageBanner(),
          const SizedBox(height: 8),
          _ToggleRow(
            label: 'Overweight / needs weight management?',
            value: _obese,
            onChanged: (v) {
              setState(() => _obese = v);
              _emit();
            },
          ),
          const SizedBox(height: 12),
          const _HealthUpgradeCard(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToggleRow(
          label: 'Add health & condition details?',
          value: _enabled,
          onChanged: (v) {
            setState(() => _enabled = v);
            _emit();
          },
        ),
        if (_enabled) ...[
          const SizedBox(height: 8),
          const _NonTriageBanner(),
          const SizedBox(height: 8),
          _ToggleRow(
            label: 'Overweight / needs weight management?',
            value: _obese,
            onChanged: (v) {
              setState(() => _obese = v);
              _emit();
            },
          ),
          if (_showsPregnant)
            _ToggleRow(
              label: 'Currently pregnant?',
              value: _pregnant,
              onChanged: (v) {
                setState(() => _pregnant = v);
                _emit();
              },
            ),
          _ToggleRow(
            label: 'Currently breeding?',
            value: _breeding,
            onChanged: (v) {
              setState(() => _breeding = v);
              _emit();
            },
          ),
          if (_isPro) ...[
            _ToggleRow(
              label: 'Currently injured?',
              value: _injured,
              onChanged: (v) async {
                if (v) {
                  final acknowledged = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const _InjuryDisclaimerDialog(),
                  );
                  if (acknowledged != true || !mounted) return;
                }
                setState(() => _injured = v);
                _emit();
              },
            ),
            if (_injured) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _injuryController,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _emit(),
                decoration: InputDecoration(
                  labelText: 'What kind of injury?',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            if (_showsHibernation)
              _ToggleRow(
                label: 'Hibernating / brumating?',
                value: _hibernatingOrBrumating,
                onChanged: (v) {
                  setState(() => _hibernatingOrBrumating = v);
                  _emit();
                },
              ),
          ],
        ],
      ],
    );
  }
}

/// Legal-protection gate shown before the injured flag can be turned on -
/// makes clear ForgeFeed only adjusts nutrition, not a substitute for
/// veterinary diagnosis or treatment. Must be explicitly acknowledged;
/// dismissing or declining leaves the toggle off.
class _InjuryDisclaimerDialog extends StatelessWidget {
  const _InjuryDisclaimerDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF242426),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF97316), width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFF97316), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Before You Continue',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'ForgeFeed is a nutritional formulation tool. It is not a diagnostic, '
              'triage, or emergency service, and it is not a substitute for examination, '
              'diagnosis, or treatment by a licensed veterinarian.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'If this animal is injured, in pain, or showing signs of distress, please '
              'seek guidance from a veterinarian or emergency animal care provider. Any '
              'dietary suggestions generated here are intended to support, not replace, '
              'professional veterinary care.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'I Understand',
                      style: TextStyle(color: Color(0xFF1A1A1C), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Persistent, always-visible banner (not a click-through gate) making clear
/// this screening feeds into the ration math, not an emergency/triage
/// assessment - shown whenever the toggle is expanded, regardless of what
/// the user answers.
class _NonTriageBanner extends StatelessWidget {
  const _NonTriageBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This screening adjusts feed math for known conditions - it is not a triage or '
              'emergency-assessment tool. If this animal is showing signs of acute illness or '
              'toxicity, contact a veterinarian immediately rather than relying on this screen.',
              style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      value: value,
      activeThumbColor: const Color(0xFFF97316),
      onChanged: onChanged,
    );
  }
}

/// Shown to Free tier in place of the health toggle - explains the feature
/// and opens the real upgrade flow.
class _HealthUpgradeCard extends StatelessWidget {
  const _HealthUpgradeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242426),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFF97316), size: 20),
              SizedBox(width: 8),
              Text(
                'Health-Based Diet Adjustments',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Upgrade to screen for pregnancy and breeding too (Pro also adds injury notes and '
            'hibernation/brumation) so your feed plan can account for it.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => const UpgradeDialog(),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(color: Color(0xFF1A1A1C), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
