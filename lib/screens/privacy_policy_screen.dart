import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'Who we are',
      'ForgeFeed is developed by Keystone Apps. This policy explains what '
          'happens to your data when you use the app.',
    ),
    (
      'Data you enter into the app',
      "Your pantry items, animal profiles, and feed formulas are stored "
          "only on your device. We never see them, and they're never "
          "uploaded anywhere - uninstalling the app deletes them for good.",
    ),
    (
      'Advertising',
      'Free and Hobby tier users are shown ads through Google AdMob. AdMob '
          "and its partners may collect an advertising ID and other "
          "device/usage data to show and measure ads. Where required by "
          "law (for example in the EU and UK), you'll be asked to consent "
          "before any of that happens, and you can change your choice "
          "later from your device's ad settings. See Google's privacy "
          "policy at https://policies.google.com/privacy for details on "
          "how they handle this data.",
    ),
    (
      'Subscriptions',
      'Hobby and Pro subscriptions are billed entirely through Google '
          'Play Billing. We only receive your subscription tier and '
          "status - never your payment details, which Google handles "
          "directly.",
    ),
    (
      "What we don't do",
      "ForgeFeed has no user accounts, collects no email addresses, and "
          "uses no analytics or tracking beyond the ad consent described "
          "above.",
    ),
    (
      'Children',
      "ForgeFeed is not directed at children under 13 and we don't "
          'knowingly collect data from them.',
    ),
    (
      'Changes to this policy',
      "If this policy changes, we'll update the effective date below and "
          "post the new version here.",
    ),
    (
      'Contact us',
      'Questions about this policy? Email [ADD YOUR CONTACT EMAIL].',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1C),
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Effective August 17, 2026',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          for (final (title, body) in _sections) ...[
            Text(
              title,
              style: const TextStyle(color: Color(0xFFF97316), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
