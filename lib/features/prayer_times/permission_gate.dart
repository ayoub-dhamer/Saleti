import 'package:flutter/material.dart';

class PermissionStep extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Future<bool> Function() requestPermission;

  const PermissionStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.requestPermission,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(description, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () async {
            final granted = await requestPermission();
            if (granted) {
              // go to next step or finish
            } else {
              // show snackbar or continue to next step anyway
            }
          },
          child: const Text('Allow'),
        ),
      ],
    );
  }
}
