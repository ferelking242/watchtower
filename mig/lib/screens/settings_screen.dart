import 'package:flutter/material.dart';
import '../widgets/screen_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  final ValueChanged<String> onSection;
  const SettingsScreen({required this.onSection, super.key});

  @override
  Widget build(BuildContext context) {
    return MigScreenScaffold(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use dark theme'),
            subtitle: const Text('Preview setting stored locally during testing'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (_) => onSection('theme'),
          ),
          const Divider(height: 28),
          Text('Migration checks',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _SettingButton(
              icon: Icons.cloud_done_outlined,
              title: 'Server status',
              onTap: () => onSection('Server status')),
          _SettingButton(
              icon: Icons.system_update_outlined,
              title: 'Check for updates',
              onTap: () => onSection('Check for updates')),
          _SettingButton(
              icon: Icons.info_outline,
              title: 'About',
              onTap: () => onSection('About Watchtower')),
        ],
      ),
    );
  }
}

class _SettingButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SettingButton(
      {required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}