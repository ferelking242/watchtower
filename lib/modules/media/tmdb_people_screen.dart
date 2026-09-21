import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/media/flixquest_app_ui_components.dart';

const _tmdbBackground = Color(0xFF0B0B11);

class TmdbCastCrewScreen extends StatefulWidget {
  final TmdbMedia media;

  const TmdbCastCrewScreen({super.key, required this.media});

  @override
  State<TmdbCastCrewScreen> createState() => _TmdbCastCrewScreenState();
}

class _TmdbCastCrewScreenState extends State<TmdbCastCrewScreen> {
  late Future<TmdbMediaDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = fetchTmdbMediaDetails(widget.media);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tmdbBackground,
      appBar: AppBar(
        title: const Text('Cast & Crew'),
        backgroundColor: _tmdbBackground,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<TmdbMediaDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PeopleLoading();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                'Impossible de charger la distribution.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          final details = snapshot.data!;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.media.displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _PeopleSectionTitle(
                        title: 'Acteurs',
                        count: details.cast.length,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              if (details.cast.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: _PeopleEmpty()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: details.cast.length,
                    itemBuilder: (_, index) {
                      final person = details.cast[index];
                      return _CastCrewRow(
                        imageUrl: person.profileUrl,
                        name: person.name,
                        subtitle: person.character,
                        onTap: () => context.push(
                          '/flixPerson',
                          extra: TmdbPersonRef(
                            id: person.id,
                            name: person.name,
                            profilePath: person.profilePath,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 26, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: _PeopleSectionTitle(
                    title: 'Équipe',
                    count: details.crew.length,
                  ),
                ),
              ),
              if (details.crew.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: _PeopleEmpty()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList.builder(
                    itemCount: details.crew.length,
                    itemBuilder: (_, index) {
                      final person = details.crew[index];
                      return _CastCrewRow(
                        imageUrl: person.profileUrl,
                        name: person.name,
                        subtitle: [
                          person.department,
                          person.job,
                        ].where((value) => value.isNotEmpty).join(' • '),
                        onTap: () => context.push(
                          '/flixPerson',
                          extra: TmdbPersonRef(
                            id: person.id,
                            name: person.name,
                            profilePath: person.profilePath,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class TmdbPersonScreen extends StatefulWidget {
  final TmdbPersonRef person;

  const TmdbPersonScreen({super.key, required this.person});

  @override
  State<TmdbPersonScreen> createState() => _TmdbPersonScreenState();
}

class _TmdbPersonScreenState extends State<TmdbPersonScreen> {
  late Future<TmdbPersonDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = fetchTmdbPersonDetails(widget.person);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tmdbBackground,
      appBar: AppBar(
        title: Text(widget.person.name),
        backgroundColor: _tmdbBackground,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<TmdbPersonDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PeopleLoading();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                'Impossible de charger cette fiche.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          final person = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 42),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PersonAvatar(url: person.profileUrl, large: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (person.knownForDepartment?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            person.knownForDepartment!,
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                        if (person.birthday?.isNotEmpty == true)
                          _PersonMeta(label: 'Naissance', value: person.birthday!),
                        if (person.deathday?.isNotEmpty == true)
                          _PersonMeta(label: 'Décès', value: person.deathday!),
                      ],
                    ),
                  ),
                ],
              ),
              if (person.placeOfBirth?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _PersonInfoLine(
                  icon: Icons.place_outlined,
                  text: person.placeOfBirth!,
                ),
              ],
              if (person.popularity != null) ...[
                const SizedBox(height: 8),
                _PersonInfoLine(
                  icon: Icons.trending_up_rounded,
                  text: 'Popularité TMDB ${person.popularity!.toStringAsFixed(2)}',
                ),
              ],
              if (person.homepage?.isNotEmpty == true ||
                  person.imdbId?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (person.homepage?.isNotEmpty == true)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(person.homepage!),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.language_rounded, size: 16),
                        label: const Text('Site'),
                      ),
                    if (person.imdbId?.isNotEmpty == true)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('https://www.imdb.com/name/${person.imdbId}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('IMDb'),
                      ),
                  ],
                ),
              ],
              if (person.biography?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 28),
                const _PeopleSectionTitle(title: 'Biographie'),
                const SizedBox(height: 10),
                _PersonTextCard(text: person.biography!),
              ],
              if (person.alsoKnownAs.isNotEmpty) ...[
                const SizedBox(height: 22),
                const _PeopleSectionTitle(title: 'Aussi connu sous'),
                const SizedBox(height: 8),
                Text(
                  person.alsoKnownAs.join(' • '),
                  style: const TextStyle(color: Colors.white70, height: 1.45),
                ),
              ],
              if (person.credits.isNotEmpty) ...[
                const SizedBox(height: 28),
                _PeopleSectionTitle(
                  title: 'Filmographie',
                  count: person.credits.length,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: person.credits.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final credit = person.credits[index];
                      return TmdbPosterCard(
                        media: credit,
                        width: 126,
                        onTap: () => context.push(
                          '/flixMediaDetail',
                          extra: credit,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CastCrewRow extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  const _CastCrewRow({
    required this.imageUrl,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 3),
      onTap: onTap,
      leading: _PersonAvatar(url: imageUrl),
      title: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle.isEmpty ? '—' : subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  final String? url;
  final bool large;

  const _PersonAvatar({required this.url, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 132.0 : 54.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(large ? 16 : 12),
      child: SizedBox(
        width: size,
        height: large ? 176 : size,
        child: url == null
            ? const ColoredBox(
                color: Color(0xFF252532),
                child: Icon(Icons.person_rounded, color: Colors.white38),
              )
            : ExtendedImage.network(
                url!,
                fit: BoxFit.cover,
                cache: true,
                loadStateChanged: (state) {
                  if (state.extendedImageLoadState == LoadState.completed) {
                    return null;
                  }
                  return const AppShimmerBlock(radius: 0);
                },
              ),
      ),
    );
  }
}

class _PersonMeta extends StatelessWidget {
  final String label;
  final String value;

  const _PersonMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Text(
        '$label • $value',
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }
}

class _PersonInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PersonInfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

class _PersonTextCard extends StatelessWidget {
  final String text;

  const _PersonTextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, height: 1.55),
      ),
    );
  }
}

class _PeopleSectionTitle extends StatelessWidget {
  final String title;
  final int? count;

  const _PeopleSectionTitle({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (count != null)
          Text(
            '$count',
            style: const TextStyle(color: Colors.white54),
          ),
      ],
    );
  }
}

class _PeopleEmpty extends StatelessWidget {
  const _PeopleEmpty();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Aucune information disponible.',
      style: TextStyle(color: Colors.white54),
    );
  }
}

class _PeopleLoading extends StatelessWidget {
  const _PeopleLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, index) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: SizedBox(height: 66, child: AppShimmerBlock()),
      ),
    );
  }
}