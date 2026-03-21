/// Page calculation utilities for multi-page score layout
/// Pure Dart implementation with no Flutter dependencies

import 'models.dart';

/// Get the page number containing a specific measure
int getPageForMeasure(int measure, LayoutConfig config, int totalMeasures) {
  if (measure < 0 || measure >= totalMeasures) {
    return 0;
  }

  final measuresPerPage = config.measuresPerSystem * config.systemsPerPage;
  return (measure / measuresPerPage).floor();
}

/// Get total number of pages for a score
int getTotalPages(int totalMeasures, LayoutConfig config) {
  if (totalMeasures == 0) {
    return 1;
  }

  final measuresPerPage = config.measuresPerSystem * config.systemsPerPage;
  return ((totalMeasures + measuresPerPage - 1) / measuresPerPage).ceil();
}

/// Get the range of measures on a specific page
(int, int) getMeasureRange(int page, LayoutConfig config, int totalMeasures) {
  final measuresPerPage = config.measuresPerSystem * config.systemsPerPage;
  final start = page * measuresPerPage;
  final end = ((page + 1) * measuresPerPage).clamp(0, totalMeasures);

  return (start, end);
}

/// Get measures for a specific system on a page
(int, int) getMeasureRangeForSystem(
  int page,
  int systemIndex,
  LayoutConfig config,
  int totalMeasures,
) {
  final measuresPerPage = config.measuresPerSystem * config.systemsPerPage;
  final pageStart = page * measuresPerPage;

  final systemStart = pageStart + (systemIndex * config.measuresPerSystem);
  final systemEnd = (systemStart + config.measuresPerSystem).clamp(0, totalMeasures);

  return (systemStart, systemEnd);
}

/// Check if a measure is visible on a given page
bool isMeasureOnPage(int measure, int page, LayoutConfig config, int totalMeasures) {
  final (start, end) = getMeasureRange(page, config, totalMeasures);
  return measure >= start && measure < end;
}

/// Get the position of a measure on its page (as a fraction 0.0-1.0)
double getMeasurePositionOnPage(
  int measure,
  int page,
  LayoutConfig config,
  int totalMeasures,
) {
  final (pageStart, pageEnd) = getMeasureRange(page, config, totalMeasures);
  if (pageStart >= pageEnd) return 0.0;

  if (measure < pageStart || measure >= pageEnd) {
    return -1.0; // Not on this page
  }

  final position = (measure - pageStart) / (pageEnd - pageStart);
  return position.clamp(0.0, 1.0);
}

/// Calculate canvas dimensions based on paper size
(double, double) getCanvasDimensions(String paperSize) {
  // Standard DPI: 96
  switch (paperSize) {
    case 'A4':
      return (816.0, 1056.0); // 210mm x 297mm at 96 DPI
    case 'Letter':
      return (816.0, 1056.0); // 8.5" x 11" at 96 DPI
    default:
      return (816.0, 1056.0); // Default to A4
  }
}

/// Calculate system and page distribution for a score
class PageDistribution {
  final int totalPages;
  final int totalSystems;
  final List<int> measuresPerPage; // Index is page number
  final List<List<int>> systemMeasureRanges; // [page][system] = (start, end)

  PageDistribution({
    required this.totalPages,
    required this.totalSystems,
    required this.measuresPerPage,
    required this.systemMeasureRanges,
  });
}

/// Calculate page and system distribution for entire score
PageDistribution calculatePageDistribution(
  int totalMeasures,
  LayoutConfig config,
) {
  if (totalMeasures == 0) {
    return PageDistribution(
      totalPages: 1,
      totalSystems: 0,
      measuresPerPage: [0],
      systemMeasureRanges: [],
    );
  }

  final totalPages = getTotalPages(totalMeasures, config);
  final measuresPerPage = <int>[];
  final systemMeasureRanges = <List<int>>[];

  int totalSystems = 0;

  for (int page = 0; page < totalPages; page++) {
    final (pageStart, pageEnd) = getMeasureRange(page, config, totalMeasures);
    final pageCount = pageEnd - pageStart;
    measuresPerPage.add(pageCount);

    // Calculate systems on this page
    for (int sys = 0; sys < config.systemsPerPage; sys++) {
      final (sysStart, sysEnd) =
          getMeasureRangeForSystem(page, sys, config, totalMeasures);
      if (sysStart >= sysEnd) break;

      systemMeasureRanges.add([sysStart, sysEnd]);
      totalSystems++;
    }
  }

  return PageDistribution(
    totalPages: totalPages,
    totalSystems: totalSystems,
    measuresPerPage: measuresPerPage,
    systemMeasureRanges: systemMeasureRanges,
  );
}

/// Get all pages that need to be rendered (including adjacent for caching)
List<int> getPagesToRender(int currentPage, int totalPages,
    {bool includeAdjacent = true}) {
  final pages = <int>{currentPage};

  if (includeAdjacent) {
    if (currentPage > 0) pages.add(currentPage - 1);
    if (currentPage < totalPages - 1) pages.add(currentPage + 1);
  }

  return pages.toList()..sort();
}

/// Calculate cache strategy for page rendering
class CacheStrategy {
  final int currentPage;
  final int totalPages;
  final List<int> pagesToKeep; // Pages to keep in cache
  final List<int> pagesToPrerender; // Pages to prerender in background
  final List<int> pagesToEvict; // Pages to remove from cache

  CacheStrategy({
    required this.currentPage,
    required this.totalPages,
    required this.pagesToKeep,
    required this.pagesToPrerender,
    required this.pagesToEvict,
  });
}

/// Calculate optimal cache strategy (LRU with prerendering)
CacheStrategy calculateCacheStrategy(
  int currentPage,
  int totalPages, {
  int cacheSize = 3,
}) {
  // Pages to keep: current + adjacent
  final pagesToKeep = getPagesToRender(currentPage, totalPages, includeAdjacent: true);

  // Pages to prerender: next 1-2 pages
  final pagesToPrerender = <int>[];
  if (currentPage + 1 < totalPages) pagesToPrerender.add(currentPage + 1);
  if (currentPage + 2 < totalPages) pagesToPrerender.add(currentPage + 2);

  // Pages to evict: any outside cache that aren't being prerendered
  final pagesToEvict = <int>[];
  for (int p = 0; p < totalPages; p++) {
    if (!pagesToKeep.contains(p) && !pagesToPrerender.contains(p)) {
      pagesToEvict.add(p);
    }
  }

  return CacheStrategy(
    currentPage: currentPage,
    totalPages: totalPages,
    pagesToKeep: pagesToKeep,
    pagesToPrerender: pagesToPrerender,
    pagesToEvict: pagesToEvict,
  );
}
