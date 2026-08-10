import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  final _emailController = TextEditingController();

  final String _webhookUrl = 'https://script.google.com/macros/s/AKfycbyjPfoKW-QwJmw4Bs6atDLCcxHnFFrE6Beqo2GulwaZJChPUA-wjciIuUm1Sx8-PwawLA/exec';

  String _selectedType = 'Request New Species';
  bool _isSubmitting = false;

  final List<String> _feedbackTypes = [
    'Request New Species',
    'Request Feed Ingredient',
    'Feature Suggestion',
    'Bug Report / Issue',
    'Other General Feedback',
  ];

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'type': _selectedType,
      'message': _feedbackController.text.trim(),
      'email': _emailController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      // Note: text/plain avoids the CORS preflight OPTIONS request on Web/Browsers
      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {'Content-Type': 'text/plain;charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      // Google Apps Script returns 200 or 302 redirect on success
      if (response.statusCode == 200 || response.statusCode == 302 || response.statusCode == 0) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted directly to our roadmap! Thank you.'),
            backgroundColor: Color(0xFF84CC16),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161F1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF84CC16), width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Color(0xFF84CC16), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Feedback & Requests',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Request Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  dropdownColor: const Color(0xFF161F1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Request Type',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _feedbackTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
                const SizedBox(height: 12),

                // Description Input
                TextFormField(
                  controller: _feedbackController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _selectedType == 'Request New Species'
                        ? 'Which species or breed would you like added?'
                        : 'Describe your request or suggestion...',
                    alignLabelWithHint: true,
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter details' : null,
                ),
                const SizedBox(height: 12),

                // Optional Email Input
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Your Email (Optional - for follow-ups)',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84CC16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFF0D1117),
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(
                              color: Color(0xFF0D1117),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}