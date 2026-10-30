import 'package:flutter/material.dart';

class ConfigurationErrorView extends StatelessWidget {
  const ConfigurationErrorView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Configuration required',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(message),
              const SizedBox(height: 16),
              const SelectableText(
                'Run with:\nflutter run --dart-define-from-file=dart_defines.json',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
