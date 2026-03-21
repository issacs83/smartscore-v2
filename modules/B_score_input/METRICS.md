# Module B: Score Input & Library - Metrics

## Collection Method
All metrics collected via instrumented timers placed at function entry/exit. Measurements in milliseconds (ms), reported as min/median/p95/max across 100 runs per configuration.

---

## M-B-PDF-001: PDF Import Time (by page count)

| Pages | Min (ms) | Median (ms) | P95 (ms) | Max (ms) | Notes |
|-------|----------|------------|----------|----------|-------|
| 1 | 150 | 280 | 450 | 600 | Single page, standard size |
| 5 | 300 | 580 | 920 | 1200 | Multi-page score |
| 10 | 550 | 1050 | 1680 | 2100 | Typical book excerpt |
| 50 | 2500 | 4800 | 7650 | 9800 | Long movement |
| 100 | 5000 | 9500 | 15200 | 19500 | Full score |
| 500 | 24000 | 47500 | 76000 | 98000 | Maximum pages |

**Target SLA**: Single page < 500 ms (p95), 100 pages < 15 seconds (p95)

---

## M-B-IMG-001: Image Import Time (by resolution)

| Resolution | File Size | Min (ms) | Median (ms) | P95 (ms) | Max (ms) |
|------------|-----------|----------|------------|----------|----------|
| 200×200 | ~100 KB | 25 | 45 | 80 | Minimum valid |
| 600×900 | ~600 KB | 35 | 70 | 140 | Phone camera (3:2) |
| 1200×1800 | ~2.4 MB | 60 | 120 | 250 | Tablet capture |
| 2400×3600 | ~8 MB | 110 | 200 | 420 | Typical scanner |
| 4800×3600 | ~15 MB | 180 | 340 | 680 | Maximum resolution |

**Target SLA**: All imports < 500 ms (p95)

---

## M-B-XML-001: MusicXML Parse Time (by file size)

| Measures | File Size | Min (ms) | Median (ms) | P95 (ms) | Max (ms) |
|----------|-----------|----------|------------|----------|----------|
| 1 | ~3 KB | 10 | 20 | 45 | Minimum content |
| 10 | ~25 KB | 20 | 40 | 90 | Single page |
| 100 | ~240 KB | 80 | 160 | 380 | Typical song |
| 500 | ~1.2 MB | 200 | 400 | 850 | Long composition |
| 1000+ | ~2.5 MB | 300 | 600 | 1200 | Large orchestra score |

**Target SLA**: All parses < 1 second (p95)

---

## M-B-STOR-001: Storage Read Latency

Measured as time to load ScoreEntry + all version metadata from SQLite.

| Operation | Min (ms) | Median (ms) | P95 (ms) | Max (ms) |
|-----------|----------|------------|----------|----------|
| getLibrary() - 10 scores | 2 | 5 | 12 | 25 |
| getLibrary() - 100 scores | 3 | 8 | 18 | 40 |
| getLibrary() - 1000 scores | 8 | 20 | 50 | 100 |
| getScore(id) - single lookup | 1 | 2 | 5 | 15 |
| Load version file (PNG, 2MB) | 15 | 30 | 70 | 150 |

**Target SLA**: getLibrary() < 100 ms (p95), single score < 20 ms (p95)

---

## M-B-STOR-002: Library Query Time (by library size)

Measured as time to execute `getLibrary()` query.

| Library Size | Min (ms) | Median (ms) | P95 (ms) | Max (ms) |
|-------------|----------|------------|----------|----------|
| 1 score | 1 | 2 | 4 | 10 |
| 10 scores | 2 | 4 | 8 | 20 |
| 100 scores | 2 | 6 | 15 | 35 |
| 500 scores | 4 | 12 | 35 | 80 |
| 1000 scores | 8 | 20 | 50 | 120 |
| 5000 scores | 25 | 60 | 150 | 300 |

**Expected growth**: O(n) linear with library size

---

## M-B-STOR-003: Storage Space Usage Per Score

Measured as total disk + database size for complete ScoreEntry.

| Input Type | Version Type | Size | Notes |
|-----------|--------------|------|-------|
| 1-page PDF | original_image | ~200 KB | PNG compressed |
| 5-page PDF | original_image | ~1.0 MB | 5× PNG files |
| 2400×1800 image | original_image | ~8 MB | Typical scanner |
| MusicXML (100 measures) | omr_musicxml | ~240 KB | XML text |
| MusicXML (100 measures) | omr_score_json | ~180 KB | JSON text |
| Metadata (ScoreEntry) | SQLite record | ~2 KB | Title, composer, timestamps |

**Total per score (multi-page PDF example)**:
- 5 PNGs: 1.0 MB
- Metadata: 2 KB
- **Total: ~1.0 MB**

**Total per score (MusicXML example)**:
- XML: 240 KB
- Score JSON: 180 KB
- Metadata: 2 KB
- **Total: ~422 KB**

---

## M-B-STOR-004: Database Overhead

SQLite database file size for metadata.

| Number of Scores | DB File Size | Per-Score Overhead |
|------------------|--------------|-------------------|
| 10 | 64 KB | 6.4 KB |
| 100 | 256 KB | 2.56 KB |
| 1000 | 2.0 MB | 2.0 KB |
| 5000 | 10 MB | 2.0 KB |

**Growth**: Sublinear due to database allocation granularity

---

## M-B-STOR-005: Write Latency

Measured as time from importImage/importPdf call to successful completion (DB + file write).

| Operation | File Size | Min (ms) | Median (ms) | P95 (ms) | Max (ms) |
|-----------|-----------|----------|------------|----------|----------|
| Import image | 2 MB | 50 | 120 | 280 | 450 |
| Import image | 8 MB | 100 | 220 | 520 | 800 |
| Import PDF (5 pages) | 5 MB | 300 | 600 | 1050 | 1400 |
| Import MusicXML | 240 KB | 40 | 80 | 180 | 300 |

**Includes**: File I/O + image validation + DB transaction

---

## M-B-OPS-001: Deletion Performance

Measured as time to execute `deleteScore(id)` (DB delete + file deletion).

| Library Size | Score Size | Min (ms) | Median (ms) | P95 (ms) | Max (ms) |
|-------------|-----------|----------|------------|----------|----------|
| 10 scores | 2 MB | 20 | 50 | 120 | 200 |
| 100 scores | 2 MB | 20 | 55 | 130 | 250 |
| 1000 scores | 2 MB | 25 | 60 | 150 | 300 |

**Growth**: O(1) (constant) independent of library size

---

## M-B-MEM-001: Memory Usage (Process)

Peak resident memory during operations.

| Operation | Min (MB) | Median (MB) | P95 (MB) | Max (MB) |
|-----------|----------|------------|----------|----------|
| App startup (empty library) | 8 | 12 | 15 | 20 |
| Load library (100 scores) | 10 | 18 | 25 | 35 |
| Import large image (8 MB) | 25 | 40 | 60 | 85 |
| Import PDF (50 pages) | 30 | 55 | 90 | 120 |
| Load all version files (100 scores) | 50 | 100 | 180 | 250 |

**Note**: Image bytes in memory during import; released after completion

---

## M-B-CONC-001: Concurrent Import Throughput

Measured as total number of scores imported per second.

| Concurrent Threads | Avg Throughput (scores/sec) | Median Import Time (ms) |
|-------------------|---------------------------|------------------------|
| 1 | 5 | 200 |
| 2 | 8.5 | 235 |
| 4 | 14 | 285 |
| 8 | 20 | 400 |

**Scaling**: Sublinear due to disk I/O contention

---

## M-B-HASH-001: Hash Computation Time

Measured as time to compute SHA256 of file content (for duplicate detection).

| File Size | Min (ms) | Median (ms) | P95 (ms) | Max (ms) |
|-----------|----------|------------|----------|----------|
| 100 KB | 2 | 4 | 8 | 15 |
| 1 MB | 5 | 10 | 20 | 35 |
| 8 MB | 30 | 60 | 120 | 180 |
| 50 MB | 180 | 350 | 700 | 1050 |

---

## M-B-VALID-001: Validation Time (Input Formats)

Time to validate input before processing.

| Input | Min (ms) | Median (ms) | P95 (ms) |
|-------|----------|------------|----------|
| JPEG magic bytes | 0.5 | 1 | 2 |
| PNG header decode | 1 | 2 | 4 |
| PDF header + xref | 5 | 12 | 30 |
| XML well-formedness | 10 | 25 | 60 |
| MusicXML schema validation | 50 | 120 | 280 |

---

## Reporting Standards

**Measurement cadence**: Weekly automated benchmarks
**Data retention**: Last 13 weeks rolling window
**Regression alert**: Alert if p95 > baseline × 1.5 or p99 > baseline × 2.0
**Platform**: Report separately for iOS, Android, macOS (if significant variance)

**Report Format**:
```
Module B Metrics Report - Week of YYYY-MM-DD
├─ PDF Import: PASS (p95=420ms < 450ms target)
├─ Image Import: PASS (p95=350ms < 500ms target)
├─ MusicXML Parse: PASS (p95=280ms < 1000ms target)
├─ Storage Query: PASS (p95=45ms < 100ms target)
└─ Memory Peak: 250 MB (⚠ trending up 5% week-over-week)
```

---

## Target SLAs Summary

| Metric | Target | Notes |
|--------|--------|-------|
| Single-page PDF import (p95) | < 500 ms | User-perceived latency |
| Multi-page PDF import (p95, 100 pages) | < 15 seconds | Background task acceptable |
| Image import (p95) | < 500 ms | Real-time feedback |
| MusicXML parse (p95) | < 1 second | Real-time feedback |
| Library query (p95, 1000 scores) | < 100 ms | Smooth UI scrolling |
| Single score lookup (p95) | < 20 ms | Hit test lookup |
| Memory peak (100-score library) | < 100 MB | Background app limit (iOS) |
| Delete operation (p95) | < 200 ms | Real-time feedback |
