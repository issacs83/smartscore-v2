import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/score_library_provider.dart';
import '../theme.dart';

// ============================================================
// Sort options
// ============================================================
enum _SortOption { lastOpened, dateImported, titleAZ, composerAZ }

extension _SortOptionLabel on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.lastOpened:
        return 'Last Opened';
      case _SortOption.dateImported:
        return 'Date Imported';
      case _SortOption.titleAZ:
        return 'Title A–Z';
      case _SortOption.composerAZ:
        return 'Composer A–Z';
    }
  }
}

// ============================================================
// Filter options
// ============================================================
enum _FilterOption { all, pdf, musicXml, scanned }

extension _FilterOptionLabel on _FilterOption {
  String get label {
    switch (this) {
      case _FilterOption.all:
        return 'All';
      case _FilterOption.pdf:
        return 'PDF';
      case _FilterOption.musicXml:
        return 'MusicXML';
      case _FilterOption.scanned:
        return 'Scanned';
    }
  }
}

// ============================================================
// HomeScreen
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = true;
  bool _isSearchActive = false;
  _SortOption _sortOption = _SortOption.lastOpened;
  _FilterOption _filterOption = _FilterOption.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScoreLibraryProvider>(context, listen: false).loadLibrary();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // Filtering and sorting
  // -------------------------------------------------------
  List<Map<String, dynamic>> _applyFiltersAndSort(
      List<Map<String, dynamic>> scores) {
    var result = List<Map<String, dynamic>>.from(scores);

    // Filter by type
    if (_filterOption != _FilterOption.all) {
      final filterKey = _filterOption == _FilterOption.pdf
          ? 'pdf'
          : _filterOption == _FilterOption.musicXml
              ? 'musicxml'
              : 'image';
      result = result.where((s) {
        final type = (s['sourceType'] ?? '').toString().toLowerCase();
        return type.contains(filterKey);
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) {
        final title = (s['title'] ?? '').toString().toLowerCase();
        final composer = (s['composer'] ?? '').toString().toLowerCase();
        return title.contains(q) || composer.contains(q);
      }).toList();
    }

    // Sort
    switch (_sortOption) {
      case _SortOption.lastOpened:
      case _SortOption.dateImported:
        result.sort((a, b) {
          final aDate = DateTime.tryParse(a['dateImported'] ?? '') ?? DateTime(0);
          final bDate = DateTime.tryParse(b['dateImported'] ?? '') ?? DateTime(0);
          return bDate.compareTo(aDate);
        });
      case _SortOption.titleAZ:
        result.sort((a, b) =>
            (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));
      case _SortOption.composerAZ:
        result.sort((a, b) => (a['composer'] ?? '')
            .toString()
            .compareTo((b['composer'] ?? '').toString()));
    }

    return result;
  }

  // -------------------------------------------------------
  // Actions
  // -------------------------------------------------------
  void _activateSearch() {
    setState(() => _isSearchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _deactivateSearch() {
    setState(() {
      _isSearchActive = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _searchFocus.unfocus();
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  'Sort By',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ..._SortOption.values.map((option) => RadioListTile<_SortOption>(
                    title: Text(option.label),
                    value: option,
                    groupValue: _sortOption,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _sortOption = val);
                      }
                      Navigator.of(ctx).pop();
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ScoreLibraryProvider library,
    Map<String, dynamic> score,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Score?'),
        content: Text(
          'Delete "${score['title']}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await library.deleteScore(score['id']);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Score deleted' : 'Delete failed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // -------------------------------------------------------
  // Build
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ScoreLibraryProvider>(
        builder: (context, library, _) {
          final scores = _applyFiltersAndSort(library.allScores);
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, library),
              if (_isSearchActive) _buildSearchBar(context),
              _buildFilterChips(context),
              if (library.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (library.lastError != null)
                SliverFillRemaining(child: _buildErrorState(context, library))
              else if (scores.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context, library),
                )
              else if (_isGridView)
                _buildGrid(context, library, scores)
              else
                _buildList(context, library, scores),
              // Bottom padding for FAB
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  // -------------------------------------------------------
  // Sliver AppBar
  // -------------------------------------------------------
  Widget _buildAppBar(BuildContext context, ScoreLibraryProvider library) {
    return SliverAppBar(
      floating: true,
      snap: true,
      title: const Text('Library'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: _activateSearch,
        ),
        IconButton(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onPressed: () => _showSortSheet(context),
        ),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          tooltip: _isGridView ? 'List view' : 'Grid view',
          onPressed: () => setState(() => _isGridView = !_isGridView),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // Search bar sliver
  // -------------------------------------------------------
  Widget _buildSearchBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SearchBar(
          controller: _searchController,
          focusNode: _searchFocus,
          hintText: 'Search scores...',
          leading: const Icon(Icons.search),
          trailing: [
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _deactivateSearch,
              ),
          ],
          onChanged: (value) => setState(() => _searchQuery = value),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Filter chips sliver
  // -------------------------------------------------------
  Widget _buildFilterChips(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: _FilterOption.values.map((option) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(option.label),
                selected: _filterOption == option,
                onSelected: (_) => setState(() => _filterOption = option),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Grid view
  // -------------------------------------------------------
  Widget _buildGrid(
    BuildContext context,
    ScoreLibraryProvider library,
    List<Map<String, dynamic>> scores,
  ) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final crossAxisCount = isTablet ? 3 : 2;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final score = scores[index];
            return _ScoreGridCard(
              score: score,
              onTap: () {
                library.selectScore(score['id']);
                context.push('/viewer/${score['id']}');
              },
              onDelete: () => _confirmDelete(context, library, score),
            );
          },
          childCount: scores.length,
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // List view
  // -------------------------------------------------------
  Widget _buildList(
    BuildContext context,
    ScoreLibraryProvider library,
    List<Map<String, dynamic>> scores,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final score = scores[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ScoreListCard(
                score: score,
                onTap: () {
                  library.selectScore(score['id']);
                  context.push('/viewer/${score['id']}');
                },
                onDelete: () => _confirmDelete(context, library, score),
              ),
            );
          },
          childCount: scores.length,
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Empty state
  // -------------------------------------------------------
  Widget _buildEmptyState(
      BuildContext context, ScoreLibraryProvider library) {
    final theme = Theme.of(context);
    final bool isFiltered =
        _filterOption != _FilterOption.all || _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered ? Icons.search_off : Icons.menu_book_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'No scores found' : 'Your library is empty',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try adjusting your search or filters.'
                  : 'Import a score to get started.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.push('/capture'),
                icon: const Icon(Icons.add),
                label: const Text('Import Score'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() {
                  _filterOption = _FilterOption.all;
                  _searchQuery = '';
                  _searchController.clear();
                  _isSearchActive = false;
                }),
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Error state
  // -------------------------------------------------------
  Widget _buildErrorState(
      BuildContext context, ScoreLibraryProvider library) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load library',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              library.lastError ?? 'Unknown error',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: library.loadLibrary,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // FAB
  // -------------------------------------------------------
  Widget _buildFab(BuildContext context) {
    return Consumer<ScoreLibraryProvider>(
      builder: (context, library, _) {
        final hasScores = library.allScores.isNotEmpty;
        if (hasScores) {
          return FloatingActionButton(
            onPressed: () => context.push('/capture'),
            tooltip: 'Import Score',
            child: const Icon(Icons.add),
          );
        }
        return FloatingActionButton.extended(
          onPressed: () => context.push('/capture'),
          icon: const Icon(Icons.add),
          label: const Text('Import Score'),
        );
      },
    );
  }
}

// ============================================================
// Score Grid Card
// ============================================================
class _ScoreGridCard extends StatelessWidget {
  final Map<String, dynamic> score;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScoreGridCard({
    required this.score,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = score['title'] ?? 'Unknown Score';
    final composer = score['composer'] ?? '';
    final sourceType = (score['sourceType'] ?? '').toString().toLowerCase();
    final pageCount = score['pageCount'] ?? 0;
    final dateImported = score['dateImported'] != null
        ? DateTime.tryParse(score['dateImported'])
        : null;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail area
              Expanded(
                child: Container(
                  color: theme.colorScheme.surfaceVariant,
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          _sourceIcon(sourceType),
                          size: 48,
                          color: _sourceColor(sourceType).withValues(alpha: 0.4),
                        ),
                      ),
                      // Source type badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _SourceBadge(sourceType: sourceType),
                      ),
                    ],
                  ),
                ),
              ),
              // Info area
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (composer.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        composer,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (pageCount > 0) ...[
                          Icon(
                            Icons.description_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$pageCount p.',
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (dateImported != null)
                          Text(
                            _relativeDate(dateImported),
                            style: theme.textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.of(ctx).pop();
                onTap();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Score List Card
// ============================================================
class _ScoreListCard extends StatelessWidget {
  final Map<String, dynamic> score;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScoreListCard({
    required this.score,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = score['title'] ?? 'Unknown Score';
    final composer = score['composer'] ?? '';
    final sourceType = (score['sourceType'] ?? '').toString().toLowerCase();
    final pageCount = score['pageCount'] ?? 0;
    final dateImported = score['dateImported'] != null
        ? DateTime.tryParse(score['dateImported'])
        : null;

    return Dismissible(
      key: Key(score['id'] ?? title),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // deletion handled externally
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showContextMenu(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _sourceColor(sourceType).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _sourceIcon(sourceType),
                    color: _sourceColor(sourceType),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (composer.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          composer,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _SourceBadge(sourceType: sourceType, compact: true),
                          const SizedBox(width: 8),
                          if (pageCount > 0)
                            Text(
                              '$pageCount pages',
                              style: theme.textTheme.labelSmall,
                            ),
                          if (pageCount > 0 && dateImported != null)
                            Text(
                              ' · ',
                              style: theme.textTheme.labelSmall,
                            ),
                          if (dateImported != null)
                            Text(
                              _relativeDate(dateImported),
                              style: theme.textTheme.labelSmall,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.of(ctx).pop();
                onTap();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Source badge widget
// ============================================================
class _SourceBadge extends StatelessWidget {
  final String sourceType;
  final bool compact;

  const _SourceBadge({required this.sourceType, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = _sourceColor(sourceType);
    final icon = _sourceIcon(sourceType);
    final label = _sourceLabel(sourceType);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}

// ============================================================
// Shared helpers
// ============================================================
IconData _sourceIcon(String sourceType) {
  if (sourceType.contains('pdf')) return Icons.picture_as_pdf;
  if (sourceType.contains('musicxml') || sourceType.contains('xml')) {
    return Icons.music_note;
  }
  if (sourceType.contains('image') || sourceType.contains('scanned')) {
    return Icons.image;
  }
  return Icons.description;
}

Color _sourceColor(String sourceType) {
  if (sourceType.contains('pdf')) return AppTheme.sourcePdf;
  if (sourceType.contains('musicxml') || sourceType.contains('xml')) {
    return AppTheme.sourceMusicXml;
  }
  if (sourceType.contains('image') || sourceType.contains('scanned')) {
    return AppTheme.sourceImage;
  }
  return const Color(0xFF72787E);
}

String _sourceLabel(String sourceType) {
  if (sourceType.contains('pdf')) return 'PDF';
  if (sourceType.contains('musicxml') || sourceType.contains('xml')) return 'MXL';
  if (sourceType.contains('image')) return 'IMG';
  return 'FILE';
}

String _relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return 'Just now';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}
