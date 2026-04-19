import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/workspace_shell.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key, this.query = ''});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionUser? session = ref.watch(schoolAdminProvider).session;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to search'),
          ),
        ),
      );
    }

    final List<SearchResultItem> results = ref.watch(
      searchResultsProvider(query),
    );

    return WorkspaceShell(
      currentSection: WorkspaceSection.search,
      session: session,
      title: 'Search',
      subtitle:
          'Search students, teachers, classes, subjects, and result sheets from one place.',
      searchInitialValue: query,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Search results',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    query.trim().isEmpty
                        ? 'Enter a search term in the sidebar or header search box.'
                        : 'Showing matches for "$query".',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No matches found.'),
                    ),
                  ...results.map((SearchResultItem item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SearchTile(item: item),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 640;
        return InkWell(
          onTap: () => context.go(item.route),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF1FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _iconFor(item.type),
                              color: const Color(0xFF155EEF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(item.subtitle),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(item.type.label),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _iconFor(item.type),
                          color: const Color(0xFF155EEF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(item.subtitle),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.type.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  IconData _iconFor(SearchEntityType type) {
    switch (type) {
      case SearchEntityType.student:
        return Icons.person_rounded;
      case SearchEntityType.teacher:
        return Icons.badge_rounded;
      case SearchEntityType.result:
        return Icons.fact_check_rounded;
      case SearchEntityType.subject:
        return Icons.menu_book_rounded;
      case SearchEntityType.schoolClass:
        return Icons.groups_rounded;
    }
  }
}
