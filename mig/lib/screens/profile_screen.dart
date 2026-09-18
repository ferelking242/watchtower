import 'package:flutter/material.dart';
import '../data/catalog.dart';
import '../widgets/screen_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  final ValueChanged<String> onSection;
  const ProfileScreen({required this.onSection, super.key});

  @override
  Widget build(BuildContext context) {
    return MigScreenScaffold(
      title: 'Profile',
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.person, size: 36),
          ),
          const SizedBox(height: 12),
          const Text('Migration tester',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Fixture profile · no authentication',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          for (final section in profileSections)
            Card(
              child: ListTile(
                leading: Icon(section.$2),
                title: Text(section.$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSection(section.$1),
              ),
            ),
        ],
      ),
    );
  }
}