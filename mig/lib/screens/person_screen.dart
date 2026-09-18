import 'package:flutter/material.dart';

class PersonScreen extends StatelessWidget {
  final String name;
  const PersonScreen({required this.name, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Person detail')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 58,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(name.substring(0, 1),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Actor and person information is displayed here without network calls, account state or playback logic.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 28),
          const _PersonFact(label: 'Known for', value: 'Drama, mystery'),
          const _PersonFact(label: 'Department', value: 'Acting'),
          const _PersonFact(label: 'Filmography', value: '12 titles'),
        ],
      ),
    );
  }
}

class _PersonFact extends StatelessWidget {
  final String label;
  final String value;
  const _PersonFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(title: Text(label), trailing: Text(value)),
      );
}