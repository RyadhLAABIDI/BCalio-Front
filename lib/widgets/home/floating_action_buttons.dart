/*import 'package:flutter/material.dart';

class FloatingActionButtons extends StatelessWidget {
  final TabController controller;

  const FloatingActionButtons({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (controller.index == 1) ...[
          FloatingActionButton(
            heroTag: 'writer',
            onPressed: () => Navigator.pushNamed(context, '/statusWriter'),
            backgroundColor: theme.colorScheme.secondary,
            mini: true,
            child: const Icon(Icons.edit, color: Colors.white),
          ),
          const SizedBox(height: 10),
        ],
        FloatingActionButton(
          heroTag: 'main',
          onPressed: () {
            if (controller.index == 1) {
              Navigator.pushNamed(context, '/statusImagePicker');
            } else {
              Navigator.pushNamed(context, '/selectContact');
            }
          },
          backgroundColor: theme.colorScheme.primary,
          child: Icon(
            controller.index == 1 ? Icons.photo_camera : Icons.comment,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
*/