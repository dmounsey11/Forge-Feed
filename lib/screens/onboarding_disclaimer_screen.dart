import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kDisclaimerAcceptedPrefsKey = 'hasAcceptedDisclaimer';

Future<bool> hasAcceptedDisclaimer() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kDisclaimerAcceptedPrefsKey) ?? false;
}

/// Mandatory click-through legal screen shown once, before the app is used
/// for the first time - confirms the user understands ForgeFeed is a
/// mathematical dietary-estimation tool, not a clinical/diagnostic system.
/// Blocks entry to the rest of the app until acknowledged.
class OnboardingDisclaimerScreen extends StatelessWidget {
  final VoidCallback onAccepted;

  const OnboardingDisclaimerScreen({super.key, required this.onAccepted});

  Future<void> _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDisclaimerAcceptedPrefsKey, true);
    onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1C),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF97316), size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    'Before You Get Started',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ForgeFeed is a mathematical calculation tool for dietary estimation. It '
                    'blends the ingredients you have on hand against published nutrient targets '
                    'to suggest a ration - it is not a clinical diagnostic system, and it does '
                    'not evaluate the health status of any specific animal.',
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'It is not a substitute for examination, diagnosis, or treatment by a '
                    'licensed veterinarian. Any dietary changes for an unwell, injured, or '
                    'high-risk animal should be made under veterinary supervision.',
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ForgeFeed is currently a prototype in active development. You may '
                    'encounter bugs, inaccurate results, or unexpected behavior - always '
                    'use your own judgment and verify important calculations.',
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'By continuing, you confirm you understand and accept this.',
                    style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _accept(context),
                      child: const Text(
                        'I Understand and Agree',
                        style: TextStyle(color: Color(0xFF1A1A1C), fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
