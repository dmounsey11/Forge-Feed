import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ration_result.dart';
import '../services/recipe_file_saver.dart';
import '../services/tier_service.dart';
import '../widgets/upgrade_dialog.dart';

class RationResultScreen extends StatelessWidget {
  final RationResult result;
  final String profileName;

  const RationResultScreen({super.key, required this.result, required this.profileName});

  String _asReceiptText() {
    final buffer = StringBuffer();
    buffer.writeln('Feed Plan - $profileName');
    buffer.writeln('Batch size: ${result.totalWeightLbs.toStringAsFixed(2)} lbs total');
    buffer.writeln();

    buffer.writeln('How to Prep:');
    for (var i = 0; i < result.instructionSteps.length; i++) {
      buffer.writeln('${i + 1}. ${result.instructionSteps[i]}');
    }
    buffer.writeln();

    buffer.writeln('Ingredients:');
    for (final item in result.baseItems) {
      buffer.writeln('- ${item.ingredient.name}: ${_formatWeight(item.lbs)}');
    }
    for (final item in result.supplementItems) {
      buffer.writeln('- ${item.ingredient.name} (supplement): ${_formatWeight(item.lbs)}');
    }
    buffer.writeln();

    buffer.writeln('Nutrient Check:');
    for (final c in result.nutrientComparisons) {
      buffer.writeln('- ${c.label}: ${c.actual.toStringAsFixed(2)} ${c.unit}');
    }

    if (result.warnings.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Safety Warnings:');
      for (final w in result.warnings) {
        buffer.writeln('- $w');
      }
    }

    buffer.writeln();
    buffer.writeln('Estimate only - not a substitute for veterinary or professional nutrition guidance.');
    return buffer.toString();
  }

  Future<void> _emailRecipe(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'Feed Recipe for $profileName',
        'body': _asReceiptText(),
      },
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open a mail app on this device.")),
      );
    }
  }

  Future<void> _downloadRecipe(BuildContext context) async {
    final filename = 'feed_plan_${profileName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.txt';
    final ok = await downloadRecipeAsFile(filename: filename, content: _asReceiptText());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Downloaded $filename' : "Downloading isn't available on this platform yet."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = context.watch<TierService>().tier;
    final isPro = tier == UserTier.pro;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1C),
        title: Text('Feed Plan - $profileName'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionCard(
            title: 'Batch Size',
            child: Text(
              '${result.totalWeightLbs.toStringAsFixed(2)} lbs total',
              style: const TextStyle(color: Color(0xFFF97316), fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          if (result.instructionSteps.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'How to Prep',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < result.instructionSteps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}.',
                            style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              result.instructionSteps[i],
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Ingredients',
            child: result.baseItems.isEmpty && result.supplementItems.isEmpty
                ? const Text('No ingredients in this batch.', style: TextStyle(color: Colors.grey))
                : Column(
                    children: [
                      ...result.baseItems.map((item) => _LineItemRow(name: item.ingredient.name, lbs: item.lbs)),
                      ...result.supplementItems.map(
                        (item) => _LineItemRow(name: '${item.ingredient.name} (supplement)', lbs: item.lbs),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Nutrient Check',
            child: Column(
              children: result.nutrientComparisons.map((c) => _NutrientRow(comparison: c)).toList(),
            ),
          ),
          if (result.excludedItemNames.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Not Used This Batch',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Not every pantry/supplement item needs to be in every batch - these '
                      "weren't selected this time (either not needed to hit targets, or a "
                      'better-fitting item was chosen instead).',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  Text(
                    result.excludedItemNames.join(', '),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
          if (result.healthNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Health / Age Adjustments Applied',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.healthNotes
                    .map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('- $n', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Safety Warnings',
              titleColor: Colors.redAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.warnings
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(w, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (isPro) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      side: const BorderSide(color: Color(0xFFF97316)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _emailRecipe(context),
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Email Recipe'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      side: const BorderSide(color: Color(0xFFF97316)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _downloadRecipe(context),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download to File'),
                  ),
                ),
              ],
            ),
          ],
          if (tier == UserTier.tier1) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF97316),
                  side: const BorderSide(color: Color(0xFFF97316)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const UpgradeDialog(),
                  );
                },
                icon: const Icon(Icons.upgrade, size: 18),
                label: const Text('Upgrade to Pro to Email or Download this Recipe'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Estimate only - not a substitute for veterinary or professional nutrition guidance.',
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

String _formatWeight(double lbs) {
  if (lbs < 1.0) {
    return '${(lbs * 16).toStringAsFixed(1)} oz';
  }
  return '${lbs.toStringAsFixed(2)} lbs';
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? titleColor;

  const _SectionCard({required this.title, required this.child, this.titleColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242426),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor ?? const Color(0xFFF97316),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final String name;
  final double lbs;

  const _LineItemRow({required this.name, required this.lbs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Text(
            _formatWeight(lbs),
            style: const TextStyle(color: Color(0xFFF97316), fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final NutrientComparison comparison;

  const _NutrientRow({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final targetLabel = comparison.targetMin == null && comparison.targetMax == null
        ? 'no target set'
        : '${comparison.targetMin?.toStringAsFixed(1) ?? '-'}-${comparison.targetMax?.toStringAsFixed(1) ?? '-'} ${comparison.unit}';

    Color statusColor;
    String statusLabel;
    switch (comparison.status) {
      case NutrientStatus.onTrack:
        statusColor = Colors.greenAccent;
        statusLabel = 'On Track';
        break;
      case NutrientStatus.low:
        statusColor = Colors.amberAccent;
        statusLabel = 'Low';
        break;
      case NutrientStatus.high:
        statusColor = Colors.redAccent;
        statusLabel = 'High';
        break;
      case NutrientStatus.unknown:
        statusColor = Colors.white38;
        statusLabel = 'Info';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(comparison.label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${comparison.actual.toStringAsFixed(2)} ${comparison.unit} (target: $targetLabel)',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor),
            ),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
