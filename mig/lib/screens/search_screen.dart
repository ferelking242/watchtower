import 'package:flutter/material.dart';
import '../data/catalog.dart';
import '../widgets/poster_card.dart';
import '../widgets/screen_scaffold.dart';

class SearchScreen extends StatefulWidget {
  final ValueChanged<MediaItem> onOpen;
  const SearchScreen({required this.onOpen, super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = const WatchtowerMetadataProvider().search(_query);
    return MigScreenScaffold(
      title: 'Search',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search movies, series or actors',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
          const SizedBox(height: 24),
          Text('${results.length} results',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 24,
            children: [
              for (final item in results)
                PosterCard(item: item, onTap: () => widget.onOpen(item)),
            ],
          ),
        ],
      ),
    );
  }
}