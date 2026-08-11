import 'package:flutter/material.dart';

enum PrepMode { days, amount }

class PrepAmountResult {
  final PrepMode mode;
  final double value;

  const PrepAmountResult({required this.mode, required this.value});
}

/// Asks how much to prep: either a number of days to feed for, or a
/// fixed amount of food (in lbs) to prep. Returns null if cancelled.
class PrepAmountDialog extends StatefulWidget {
  const PrepAmountDialog({super.key});

  @override
  State<PrepAmountDialog> createState() => _PrepAmountDialogState();
}

class _PrepAmountDialogState extends State<PrepAmountDialog> {
  PrepMode _mode = PrepMode.days;
  final _valueController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

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
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How much are you prepping?',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<PrepMode>(
              segments: const [
                ButtonSegment(value: PrepMode.days, label: Text('Days to Prep')),
                ButtonSegment(value: PrepMode.amount, label: Text('Amount (lbs)')),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => setState(() => _mode = selection.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1C),
                foregroundColor: Colors.white60,
                selectedBackgroundColor: const Color(0xFFF97316),
                selectedForegroundColor: const Color(0xFF1A1A1C),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: _mode == PrepMode.days ? 'Number of days' : 'Amount of food (lbs)',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: const Color(0xFF1A1A1C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final value = double.tryParse(_valueController.text.trim());
                  if (value != null && value > 0) {
                    Navigator.of(context).pop(PrepAmountResult(mode: _mode, value: value));
                  }
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(color: Color(0xFF1A1A1C), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
